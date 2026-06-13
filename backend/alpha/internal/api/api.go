// Package api wires the HTTP+JSON handlers for the alpha server.
//
// All endpoints under /v1/. Bearer token in `Authorization: Bearer <token>`.
// Bodies are JSON; sizes are bounded.
//
// Auth model (alpha-grade):
//   - Client generates a random 32-byte device_secret on first run.
//   - Registration: client sends handle + device_secret_b64. Server stores it.
//   - Login: client requests challenge nonce. Client computes
//     hmac_b64 = HMAC-SHA256(device_secret, nonce). Server verifies.
//   - On success, server issues a 30-day bearer token.
//
// This is intentionally NOT the production Phase 7 design. Phase 7 swaps
// in the libsignal-backed Ed25519 identity attestation flow. Until then
// the alpha auth keeps the contract shape identical (handle + key + signature)
// while compiling without third-party crypto.
package api

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/velix/backend/alpha/internal/ids"
	"github.com/velix/backend/alpha/internal/store"
)

const deviceSecretLen = 32

// Server is the HTTP handler.
type Server struct {
	Store  *store.Store
	Logger *log.Logger
}

// Handler builds the route table.
func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()

	// Health.
	mux.HandleFunc("GET /v1/healthz", s.handleHealthz)
	mux.HandleFunc("GET /v1/readyz", s.handleHealthz)

	// Auth.
	mux.HandleFunc("POST /v1/register", s.handleRegister)
	mux.HandleFunc("GET /v1/challenge", s.handleChallenge)
	mux.HandleFunc("POST /v1/login", s.handleLogin)

	// Authenticated.
	mux.HandleFunc("GET /v1/me", s.requireAuth(s.handleMe))
	mux.HandleFunc("GET /v1/users/lookup", s.requireAuth(s.handleLookup))
	mux.HandleFunc("GET /v1/conversations", s.requireAuth(s.handleListConversations))
	mux.HandleFunc("POST /v1/conversations", s.requireAuth(s.handleOpenConversation))
	mux.HandleFunc("GET /v1/conversations/{id}/messages", s.requireAuth(s.handleListMessages))
	mux.HandleFunc("POST /v1/conversations/{id}/messages", s.requireAuth(s.handleSendMessage))

	return s.withCORS(s.withLogging(mux))
}

// ----- Middleware ---------------------------------------------------------

func (s *Server) withCORS(h http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Authorization,Content-Type")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		h.ServeHTTP(w, r)
	})
}

func (s *Server) withLogging(h http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rw := &recordingWriter{ResponseWriter: w, status: 200}
		h.ServeHTTP(rw, r)
		s.Logger.Printf("%s %s %d %s", r.Method, r.URL.Path, rw.status, time.Since(start))
	})
}

type recordingWriter struct {
	http.ResponseWriter
	status int
}

func (r *recordingWriter) WriteHeader(code int) {
	r.status = code
	r.ResponseWriter.WriteHeader(code)
}

func (s *Server) requireAuth(h func(http.ResponseWriter, *http.Request, string)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		authz := r.Header.Get("Authorization")
		if !strings.HasPrefix(authz, "Bearer ") {
			writeError(w, http.StatusUnauthorized, "missing bearer")
			return
		}
		token := strings.TrimPrefix(authz, "Bearer ")
		sess, ok := s.Store.GetSession(token)
		if !ok {
			writeError(w, http.StatusUnauthorized, "invalid or expired token")
			return
		}
		h(w, r, sess.AccountID)
	}
}

// ----- Health -------------------------------------------------------------

func (s *Server) handleHealthz(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{"status": "ok", "time": time.Now().UTC()})
}

// ----- Register -----------------------------------------------------------

type registerRequest struct {
	Handle           string `json:"handle"`
	DeviceSecretB64  string `json:"device_secret_b64"`
}

type registerResponse struct {
	AccountID string    `json:"account_id"`
	Handle    string    `json:"handle"`
	Token     string    `json:"token"`
	ExpiresAt time.Time `json:"expires_at"`
}

var handleRe = regexp.MustCompile(`^[a-zA-Z0-9._-]{3,32}$`)

func (s *Server) handleRegister(w http.ResponseWriter, r *http.Request) {
	var req registerRequest
	if err := readJSON(r, &req, 4*1024); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if !handleRe.MatchString(req.Handle) {
		writeError(w, http.StatusBadRequest, "handle must be 3-32 chars, [a-zA-Z0-9._-]")
		return
	}
	secret, err := base64.StdEncoding.DecodeString(req.DeviceSecretB64)
	if err != nil || len(secret) != deviceSecretLen {
		writeError(w, http.StatusBadRequest,
			fmt.Sprintf("device_secret_b64 must decode to %d bytes", deviceSecretLen))
		return
	}
	now := time.Now().UTC()
	acc := store.Account{
		ID:          ids.New(),
		Handle:      req.Handle,
		IdentityPub: secret, // Stored as opaque secret. Not exposed via /me.
		CreatedAt:   now,
	}
	if err := s.Store.CreateAccount(acc); err != nil {
		if errors.Is(err, store.ErrConflict) {
			writeError(w, http.StatusConflict, "handle taken")
			return
		}
		writeError(w, http.StatusInternalServerError, "create failed")
		return
	}
	sess := store.Session{
		Token:     ids.NewToken(),
		AccountID: acc.ID,
		IssuedAt:  now,
		ExpiresAt: now.Add(30 * 24 * time.Hour),
	}
	s.Store.PutSession(sess)
	writeJSON(w, http.StatusOK, registerResponse{
		AccountID: acc.ID, Handle: acc.Handle, Token: sess.Token, ExpiresAt: sess.ExpiresAt,
	})
}

// ----- Challenge / Login --------------------------------------------------

type challengeResponse struct {
	NonceB64  string    `json:"nonce_b64"`
	ExpiresAt time.Time `json:"expires_at"`
}

func (s *Server) handleChallenge(w http.ResponseWriter, r *http.Request) {
	accountID := r.URL.Query().Get("account_id")
	if accountID == "" {
		writeError(w, http.StatusBadRequest, "account_id required")
		return
	}
	if _, ok := s.Store.GetAccount(accountID); !ok {
		writeError(w, http.StatusNotFound, "account not found")
		return
	}
	nonce := make([]byte, 32)
	if _, err := rand.Read(nonce); err != nil {
		writeError(w, http.StatusInternalServerError, "rng failed")
		return
	}
	now := time.Now().UTC()
	c := store.Challenge{
		AccountID: accountID,
		Nonce:     nonce,
		IssuedAt:  now,
		ExpiresAt: now.Add(2 * time.Minute),
	}
	s.Store.PutChallenge(c)
	writeJSON(w, http.StatusOK, challengeResponse{
		NonceB64:  base64.StdEncoding.EncodeToString(nonce),
		ExpiresAt: c.ExpiresAt,
	})
}

type loginRequest struct {
	AccountID string `json:"account_id"`
	NonceB64  string `json:"nonce_b64"`
	HMACB64   string `json:"hmac_b64"`
}

type loginResponse struct {
	Token     string    `json:"token"`
	ExpiresAt time.Time `json:"expires_at"`
}

func (s *Server) handleLogin(w http.ResponseWriter, r *http.Request) {
	var req loginRequest
	if err := readJSON(r, &req, 4*1024); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	acc, ok := s.Store.GetAccount(req.AccountID)
	if !ok {
		writeError(w, http.StatusUnauthorized, "unknown account")
		return
	}
	nonce, err := base64.StdEncoding.DecodeString(req.NonceB64)
	if err != nil {
		writeError(w, http.StatusBadRequest, "nonce_b64 invalid")
		return
	}
	mac, err := base64.StdEncoding.DecodeString(req.HMACB64)
	if err != nil || len(mac) != sha256.Size {
		writeError(w, http.StatusBadRequest, "hmac_b64 invalid")
		return
	}
	c, ok := s.Store.ConsumeChallenge(nonce)
	if !ok || c.AccountID != req.AccountID {
		writeError(w, http.StatusUnauthorized, "challenge invalid or expired")
		return
	}
	expected := hmac.New(sha256.New, acc.IdentityPub)
	expected.Write(nonce)
	expectedSum := expected.Sum(nil)
	if !hmac.Equal(mac, expectedSum) {
		writeError(w, http.StatusUnauthorized, "hmac does not verify")
		return
	}
	now := time.Now().UTC()
	sess := store.Session{
		Token:     ids.NewToken(),
		AccountID: acc.ID,
		IssuedAt:  now,
		ExpiresAt: now.Add(30 * 24 * time.Hour),
	}
	s.Store.PutSession(sess)
	writeJSON(w, http.StatusOK, loginResponse{Token: sess.Token, ExpiresAt: sess.ExpiresAt})
}

// ----- Me / Lookup --------------------------------------------------------

type meResponse struct {
	AccountID string `json:"account_id"`
	Handle    string `json:"handle"`
}

func (s *Server) handleMe(w http.ResponseWriter, r *http.Request, accountID string) {
	acc, ok := s.Store.GetAccount(accountID)
	if !ok {
		writeError(w, http.StatusNotFound, "account not found")
		return
	}
	writeJSON(w, http.StatusOK, meResponse{AccountID: acc.ID, Handle: acc.Handle})
}

func (s *Server) handleLookup(w http.ResponseWriter, r *http.Request, _ string) {
	handle := r.URL.Query().Get("handle")
	if handle == "" {
		writeError(w, http.StatusBadRequest, "handle required")
		return
	}
	acc, ok := s.Store.FindAccountByHandle(handle)
	if !ok {
		writeError(w, http.StatusNotFound, "user not found")
		return
	}
	writeJSON(w, http.StatusOK, meResponse{AccountID: acc.ID, Handle: acc.Handle})
}

// ----- Conversations ------------------------------------------------------

type conversationDTO struct {
	ID         string    `json:"id"`
	PeerID     string    `json:"peer_account_id"`
	Title      string    `json:"title"`
	LastActive time.Time `json:"last_active_at"`
	Preview    string    `json:"last_message_preview"`
}

func toConversationDTO(me string, c store.Conversation) conversationDTO {
	peer := c.MemberA
	if peer == me {
		peer = c.MemberB
	}
	return conversationDTO{
		ID:         c.ID,
		PeerID:     peer,
		Title:      c.Title,
		LastActive: c.LastActive,
		Preview:    c.Preview,
	}
}

func (s *Server) handleListConversations(w http.ResponseWriter, r *http.Request, me string) {
	cs := s.Store.ListConversationsFor(me)
	out := make([]conversationDTO, 0, len(cs))
	for _, c := range cs {
		out = append(out, toConversationDTO(me, c))
	}
	writeJSON(w, http.StatusOK, map[string]any{"conversations": out})
}

type openConversationRequest struct {
	PeerAccountID string `json:"peer_account_id"`
	Title         string `json:"title"`
}

func (s *Server) handleOpenConversation(w http.ResponseWriter, r *http.Request, me string) {
	var req openConversationRequest
	if err := readJSON(r, &req, 4*1024); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if req.PeerAccountID == "" || req.PeerAccountID == me {
		writeError(w, http.StatusBadRequest, "peer_account_id required and must differ from caller")
		return
	}
	if _, ok := s.Store.GetAccount(req.PeerAccountID); !ok {
		writeError(w, http.StatusNotFound, "peer not found")
		return
	}
	title := req.Title
	if title == "" {
		title = "Conversation"
	}
	c := s.Store.UpsertConversationFor(me, req.PeerAccountID, title, time.Now().UTC(), ids.New)
	writeJSON(w, http.StatusOK, toConversationDTO(me, c))
}

// ----- Messages -----------------------------------------------------------

type messageDTO struct {
	ID             string    `json:"id"`
	ConversationID string    `json:"conversation_id"`
	SenderID       string    `json:"sender_id"`
	Kind           string    `json:"kind"`
	CiphertextB64  string    `json:"ciphertext_b64"`
	SentAt         time.Time `json:"sent_at"`
}

func toMessageDTO(m store.Message) messageDTO {
	return messageDTO{
		ID:             m.ID,
		ConversationID: m.ConversationID,
		SenderID:       m.SenderID,
		Kind:           m.Kind,
		CiphertextB64:  m.CiphertextB64,
		SentAt:         m.SentAt,
	}
}

func (s *Server) handleListMessages(w http.ResponseWriter, r *http.Request, me string) {
	cid := r.PathValue("id")
	if cid == "" {
		writeError(w, http.StatusBadRequest, "conversation id required")
		return
	}
	if !s.Store.IsMember(cid, me) {
		writeError(w, http.StatusForbidden, "not a member")
		return
	}
	ms := s.Store.ListMessages(cid)
	out := make([]messageDTO, 0, len(ms))
	for _, m := range ms {
		out = append(out, toMessageDTO(m))
	}
	writeJSON(w, http.StatusOK, map[string]any{"messages": out})
}

type sendMessageRequest struct {
	Kind          string `json:"kind"`
	CiphertextB64 string `json:"ciphertext_b64"`
	Preview       string `json:"preview"`
}

func (s *Server) handleSendMessage(w http.ResponseWriter, r *http.Request, me string) {
	cid := r.PathValue("id")
	if cid == "" {
		writeError(w, http.StatusBadRequest, "conversation id required")
		return
	}
	if !s.Store.IsMember(cid, me) {
		writeError(w, http.StatusForbidden, "not a member")
		return
	}
	var req sendMessageRequest
	if err := readJSON(r, &req, 256*1024); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	kind := req.Kind
	if kind == "" {
		kind = "text"
	}
	if _, err := base64.StdEncoding.DecodeString(req.CiphertextB64); err != nil {
		writeError(w, http.StatusBadRequest, "ciphertext_b64 must be valid base64")
		return
	}
	preview := req.Preview
	if len(preview) > 96 {
		preview = preview[:96]
	}
	m := store.Message{
		ID:             ids.New(),
		ConversationID: cid,
		SenderID:       me,
		Kind:           kind,
		CiphertextB64:  req.CiphertextB64,
		SentAt:         time.Now().UTC(),
	}
	s.Store.AppendMessage(m, preview)
	writeJSON(w, http.StatusOK, toMessageDTO(m))
}

// ----- Helpers -----------------------------------------------------------

func writeJSON(w http.ResponseWriter, code int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	if err := json.NewEncoder(w).Encode(body); err != nil {
		_ = err
	}
}

func writeError(w http.ResponseWriter, code int, msg string) {
	writeJSON(w, code, map[string]any{"error": msg})
}

func readJSON(r *http.Request, dest any, maxBytes int64) error {
	if r.Body == nil {
		return fmt.Errorf("missing body")
	}
	r.Body = http.MaxBytesReader(nil, r.Body, maxBytes)
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(dest); err != nil {
		if errors.Is(err, io.EOF) {
			return fmt.Errorf("empty body")
		}
		return err
	}
	return nil
}
