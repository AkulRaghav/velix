// Package store is the alpha in-memory data store + JSON snapshot.
//
// Concurrency: a single sync.RWMutex guards everything. Volume is small;
// the alpha is dev-grade.
package store

import (
	"encoding/json"
	"errors"
	"os"
	"sort"
	"sync"
	"time"
)

// Account is a registered user.
type Account struct {
	ID            string    `json:"id"`
	Handle        string    `json:"handle"`
	IdentityPub   []byte    `json:"identity_pubkey"`
	CreatedAt     time.Time `json:"created_at"`
}

// Session is an issued bearer token.
type Session struct {
	Token     string    `json:"token"`
	AccountID string    `json:"account_id"`
	IssuedAt  time.Time `json:"issued_at"`
	ExpiresAt time.Time `json:"expires_at"`
}

// Conversation is a 1:1 thread between two accounts.
type Conversation struct {
	ID          string    `json:"id"`
	MemberA     string    `json:"member_a"`
	MemberB     string    `json:"member_b"`
	Title       string    `json:"title"`
	CreatedAt   time.Time `json:"created_at"`
	LastActive  time.Time `json:"last_active"`
	Preview     string    `json:"last_message_preview"`
}

// Message is a single message; ciphertext is opaque to the server.
type Message struct {
	ID             string    `json:"id"`
	ConversationID string    `json:"conversation_id"`
	SenderID       string    `json:"sender_id"`
	Kind           string    `json:"kind"`
	CiphertextB64  string    `json:"ciphertext_b64"`
	SentAt         time.Time `json:"sent_at"`
}

// Challenge is an outstanding login challenge.
type Challenge struct {
	AccountID string    `json:"account_id"`
	Nonce     []byte    `json:"nonce"`
	IssuedAt  time.Time `json:"issued_at"`
	ExpiresAt time.Time `json:"expires_at"`
}

// Snapshot is the on-disk JSON layout.
type Snapshot struct {
	Accounts      map[string]Account      `json:"accounts"`
	Handles       map[string]string       `json:"handles_to_account_id"`
	Sessions      map[string]Session      `json:"sessions"`
	Conversations map[string]Conversation `json:"conversations"`
	Messages      map[string][]Message    `json:"messages_by_conversation"`
	Challenges    map[string]Challenge    `json:"challenges_by_nonce"`
}

// Store is the synchronized state owner.
type Store struct {
	mu sync.RWMutex
	s  Snapshot
}

// New creates an empty store.
func New() *Store {
	return &Store{
		s: Snapshot{
			Accounts:      map[string]Account{},
			Handles:       map[string]string{},
			Sessions:      map[string]Session{},
			Conversations: map[string]Conversation{},
			Messages:      map[string][]Message{},
			Challenges:    map[string]Challenge{},
		},
	}
}

// Common errors.
var (
	ErrConflict = errors.New("conflict")
)

// Load reads a snapshot from disk. Missing file is not an error.
func (st *Store) Load(path string) error {
	bs, err := os.ReadFile(path)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return nil
		}
		return err
	}
	st.mu.Lock()
	defer st.mu.Unlock()
	if len(bs) == 0 {
		return nil
	}
	var snap Snapshot
	if err := json.Unmarshal(bs, &snap); err != nil {
		return err
	}
	if snap.Accounts == nil {
		snap.Accounts = map[string]Account{}
	}
	if snap.Handles == nil {
		snap.Handles = map[string]string{}
	}
	if snap.Sessions == nil {
		snap.Sessions = map[string]Session{}
	}
	if snap.Conversations == nil {
		snap.Conversations = map[string]Conversation{}
	}
	if snap.Messages == nil {
		snap.Messages = map[string][]Message{}
	}
	if snap.Challenges == nil {
		snap.Challenges = map[string]Challenge{}
	}
	st.s = snap
	return nil
}

// Save writes the snapshot to disk.
func (st *Store) Save(path string) error {
	st.mu.RLock()
	defer st.mu.RUnlock()
	bs, err := json.MarshalIndent(st.s, "", "  ")
	if err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, bs, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

// ----- Accounts -----------------------------------------------------------

func (st *Store) CreateAccount(a Account) error {
	st.mu.Lock()
	defer st.mu.Unlock()
	if _, ok := st.s.Accounts[a.ID]; ok {
		return ErrConflict
	}
	if _, ok := st.s.Handles[a.Handle]; ok {
		return ErrConflict
	}
	st.s.Accounts[a.ID] = a
	st.s.Handles[a.Handle] = a.ID
	return nil
}

func (st *Store) GetAccount(id string) (Account, bool) {
	st.mu.RLock()
	defer st.mu.RUnlock()
	a, ok := st.s.Accounts[id]
	return a, ok
}

func (st *Store) FindAccountByHandle(handle string) (Account, bool) {
	st.mu.RLock()
	defer st.mu.RUnlock()
	id, ok := st.s.Handles[handle]
	if !ok {
		return Account{}, false
	}
	a, ok := st.s.Accounts[id]
	return a, ok
}

// ----- Sessions -----------------------------------------------------------

func (st *Store) PutSession(s Session) {
	st.mu.Lock()
	defer st.mu.Unlock()
	st.s.Sessions[s.Token] = s
}

func (st *Store) GetSession(token string) (Session, bool) {
	st.mu.RLock()
	defer st.mu.RUnlock()
	s, ok := st.s.Sessions[token]
	if !ok {
		return Session{}, false
	}
	if time.Now().After(s.ExpiresAt) {
		return Session{}, false
	}
	return s, true
}

// ----- Challenges ---------------------------------------------------------

func (st *Store) PutChallenge(c Challenge) {
	st.mu.Lock()
	defer st.mu.Unlock()
	st.s.Challenges[encodeNonceKey(c.Nonce)] = c
}

func (st *Store) ConsumeChallenge(nonce []byte) (Challenge, bool) {
	st.mu.Lock()
	defer st.mu.Unlock()
	key := encodeNonceKey(nonce)
	c, ok := st.s.Challenges[key]
	if !ok {
		return Challenge{}, false
	}
	delete(st.s.Challenges, key)
	if time.Now().After(c.ExpiresAt) {
		return Challenge{}, false
	}
	return c, true
}

// ----- Conversations ------------------------------------------------------

func (st *Store) UpsertConversationFor(memberA, memberB, title string, now time.Time, idGen func() string) Conversation {
	st.mu.Lock()
	defer st.mu.Unlock()
	for _, c := range st.s.Conversations {
		if (c.MemberA == memberA && c.MemberB == memberB) || (c.MemberA == memberB && c.MemberB == memberA) {
			return c
		}
	}
	c := Conversation{
		ID:         idGen(),
		MemberA:    memberA,
		MemberB:    memberB,
		Title:      title,
		CreatedAt:  now,
		LastActive: now,
	}
	st.s.Conversations[c.ID] = c
	return c
}

func (st *Store) GetConversation(id string) (Conversation, bool) {
	st.mu.RLock()
	defer st.mu.RUnlock()
	c, ok := st.s.Conversations[id]
	return c, ok
}

func (st *Store) ListConversationsFor(accountID string) []Conversation {
	st.mu.RLock()
	defer st.mu.RUnlock()
	out := []Conversation{}
	for _, c := range st.s.Conversations {
		if c.MemberA == accountID || c.MemberB == accountID {
			out = append(out, c)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].LastActive.After(out[j].LastActive) })
	return out
}

// ----- Messages -----------------------------------------------------------

func (st *Store) AppendMessage(m Message, preview string) {
	st.mu.Lock()
	defer st.mu.Unlock()
	st.s.Messages[m.ConversationID] = append(st.s.Messages[m.ConversationID], m)
	if c, ok := st.s.Conversations[m.ConversationID]; ok {
		c.LastActive = m.SentAt
		c.Preview = preview
		st.s.Conversations[m.ConversationID] = c
	}
}

func (st *Store) ListMessages(conversationID string) []Message {
	st.mu.RLock()
	defer st.mu.RUnlock()
	src := st.s.Messages[conversationID]
	out := make([]Message, len(src))
	copy(out, src)
	sort.Slice(out, func(i, j int) bool { return out[i].SentAt.Before(out[j].SentAt) })
	return out
}

// ----- Member check -------------------------------------------------------

func (st *Store) IsMember(conversationID, accountID string) bool {
	st.mu.RLock()
	defer st.mu.RUnlock()
	c, ok := st.s.Conversations[conversationID]
	if !ok {
		return false
	}
	return c.MemberA == accountID || c.MemberB == accountID
}

// encodeNonceKey converts the nonce bytes to a stable string key.
func encodeNonceKey(b []byte) string {
	const alphabet = "0123456789abcdef"
	out := make([]byte, len(b)*2)
	for i, v := range b {
		out[i*2] = alphabet[v>>4]
		out[i*2+1] = alphabet[v&0x0f]
	}
	return string(out)
}
