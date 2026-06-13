package api_test

import (
	"bytes"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"io"
	"log"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/velix/backend/alpha/internal/api"
	"github.com/velix/backend/alpha/internal/store"
)

func newTestServer(t *testing.T) *httptest.Server {
	t.Helper()
	st := store.New()
	srv := &api.Server{Store: st, Logger: log.New(io.Discard, "", 0)}
	return httptest.NewServer(srv.Handler())
}

func mustPost(t *testing.T, ts *httptest.Server, path, token string, body any) (int, []byte) {
	t.Helper()
	bs, _ := json.Marshal(body)
	req, _ := http.NewRequest(http.MethodPost, ts.URL+path, bytes.NewReader(bs))
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("post %s: %v", path, err)
	}
	defer res.Body.Close()
	out, _ := io.ReadAll(res.Body)
	return res.StatusCode, out
}

func mustGet(t *testing.T, ts *httptest.Server, path, token string) (int, []byte) {
	t.Helper()
	req, _ := http.NewRequest(http.MethodGet, ts.URL+path, nil)
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("get %s: %v", path, err)
	}
	defer res.Body.Close()
	out, _ := io.ReadAll(res.Body)
	return res.StatusCode, out
}

func freshSecret(t *testing.T) []byte {
	t.Helper()
	s := make([]byte, 32)
	if _, err := rand.Read(s); err != nil {
		t.Fatal(err)
	}
	return s
}

func computeHMAC(secret, nonce []byte) []byte {
	h := hmac.New(sha256.New, secret)
	h.Write(nonce)
	return h.Sum(nil)
}

func TestE2E_RegisterLoginSendList(t *testing.T) {
	ts := newTestServer(t)
	defer ts.Close()

	secretA := freshSecret(t)
	secretB := freshSecret(t)

	// Register A.
	code, body := mustPost(t, ts, "/v1/register", "", map[string]any{
		"handle":            "alice",
		"device_secret_b64": base64.StdEncoding.EncodeToString(secretA),
	})
	if code != http.StatusOK {
		t.Fatalf("register A: %d %s", code, body)
	}
	var regA struct {
		AccountID string `json:"account_id"`
		Handle    string `json:"handle"`
		Token     string `json:"token"`
	}
	if err := json.Unmarshal(body, &regA); err != nil {
		t.Fatal(err)
	}
	if regA.AccountID == "" || regA.Token == "" {
		t.Fatalf("register A: empty fields: %s", body)
	}

	// Register B.
	code, body = mustPost(t, ts, "/v1/register", "", map[string]any{
		"handle":            "bob",
		"device_secret_b64": base64.StdEncoding.EncodeToString(secretB),
	})
	if code != http.StatusOK {
		t.Fatalf("register B: %d %s", code, body)
	}
	var regB struct {
		AccountID string `json:"account_id"`
		Handle    string `json:"handle"`
		Token     string `json:"token"`
	}
	_ = json.Unmarshal(body, &regB)
	if regB.AccountID == "" {
		t.Fatalf("register B: %s", body)
	}

	// Try registering A again with same handle → 409.
	code, _ = mustPost(t, ts, "/v1/register", "", map[string]any{
		"handle":            "alice",
		"device_secret_b64": base64.StdEncoding.EncodeToString(secretA),
	})
	if code != http.StatusConflict {
		t.Fatalf("expected 409 on duplicate handle; got %d", code)
	}

	// Login flow for A: get challenge, HMAC, post.
	code, body = mustGet(t, ts, "/v1/challenge?account_id="+regA.AccountID, "")
	if code != http.StatusOK {
		t.Fatalf("challenge: %d %s", code, body)
	}
	var ch struct {
		NonceB64 string `json:"nonce_b64"`
	}
	_ = json.Unmarshal(body, &ch)
	nonce, err := base64.StdEncoding.DecodeString(ch.NonceB64)
	if err != nil {
		t.Fatal(err)
	}
	mac := computeHMAC(secretA, nonce)
	code, body = mustPost(t, ts, "/v1/login", "", map[string]any{
		"account_id": regA.AccountID,
		"nonce_b64":  ch.NonceB64,
		"hmac_b64":   base64.StdEncoding.EncodeToString(mac),
	})
	if code != http.StatusOK {
		t.Fatalf("login: %d %s", code, body)
	}
	var login struct {
		Token string `json:"token"`
	}
	_ = json.Unmarshal(body, &login)
	if login.Token == "" || login.Token == regA.Token {
		t.Fatalf("login token should be fresh: %q vs %q", login.Token, regA.Token)
	}

	// Bad HMAC fails.
	_, body = mustGet(t, ts, "/v1/challenge?account_id="+regA.AccountID, "")
	var ch2 struct {
		NonceB64 string `json:"nonce_b64"`
	}
	_ = json.Unmarshal(body, &ch2)
	nonce2, _ := base64.StdEncoding.DecodeString(ch2.NonceB64)
	wrongMac := computeHMAC(secretB, nonce2)
	code, _ = mustPost(t, ts, "/v1/login", "", map[string]any{
		"account_id": regA.AccountID,
		"nonce_b64":  ch2.NonceB64,
		"hmac_b64":   base64.StdEncoding.EncodeToString(wrongMac),
	})
	if code != http.StatusUnauthorized {
		t.Fatalf("expected 401 for wrong HMAC; got %d", code)
	}

	// /v1/me works for A.
	code, body = mustGet(t, ts, "/v1/me", regA.Token)
	if code != http.StatusOK {
		t.Fatalf("me: %d %s", code, body)
	}

	// Lookup B by handle.
	code, body = mustGet(t, ts, "/v1/users/lookup?handle=bob", regA.Token)
	if code != http.StatusOK {
		t.Fatalf("lookup: %d %s", code, body)
	}
	var lookup struct {
		AccountID string `json:"account_id"`
	}
	_ = json.Unmarshal(body, &lookup)
	if lookup.AccountID != regB.AccountID {
		t.Fatalf("lookup mismatch: %q vs %q", lookup.AccountID, regB.AccountID)
	}

	// A opens a conversation with B.
	code, body = mustPost(t, ts, "/v1/conversations", regA.Token, map[string]any{
		"peer_account_id": regB.AccountID,
		"title":           "Hello bob",
	})
	if code != http.StatusOK {
		t.Fatalf("open: %d %s", code, body)
	}
	var conv struct {
		ID string `json:"id"`
	}
	_ = json.Unmarshal(body, &conv)

	// Send a message from A.
	plain := []byte("hello bob")
	code, body = mustPost(t, ts, "/v1/conversations/"+conv.ID+"/messages", regA.Token, map[string]any{
		"kind":           "text",
		"ciphertext_b64": base64.StdEncoding.EncodeToString(plain),
		"preview":        "hello bob",
	})
	if code != http.StatusOK {
		t.Fatalf("send: %d %s", code, body)
	}

	// B fetches messages.
	code, body = mustGet(t, ts, "/v1/conversations/"+conv.ID+"/messages", regB.Token)
	if code != http.StatusOK {
		t.Fatalf("list: %d %s", code, body)
	}
	if !strings.Contains(string(body), base64.StdEncoding.EncodeToString(plain)) {
		t.Fatalf("expected ciphertext in list response: %s", body)
	}

	// B's conversations list includes this one.
	code, body = mustGet(t, ts, "/v1/conversations", regB.Token)
	if code != http.StatusOK {
		t.Fatalf("list conv: %d %s", code, body)
	}
	if !strings.Contains(string(body), conv.ID) {
		t.Fatalf("expected B to see the conversation: %s", body)
	}

	// Forbid: a third party tries to read.
	secretC := freshSecret(t)
	code, body = mustPost(t, ts, "/v1/register", "", map[string]any{
		"handle":            "charlie",
		"device_secret_b64": base64.StdEncoding.EncodeToString(secretC),
	})
	if code != http.StatusOK {
		t.Fatalf("register C: %d %s", code, body)
	}
	var regC struct {
		Token string `json:"token"`
	}
	_ = json.Unmarshal(body, &regC)
	code, _ = mustGet(t, ts, "/v1/conversations/"+conv.ID+"/messages", regC.Token)
	if code != http.StatusForbidden {
		t.Fatalf("expected 403 for non-member; got %d", code)
	}
}

func TestRegister_RejectsBadHandle(t *testing.T) {
	ts := newTestServer(t)
	defer ts.Close()
	secret := make([]byte, 32)
	cases := []string{"", "a", "ab", "x*y", strings.Repeat("a", 33)}
	for _, h := range cases {
		code, _ := mustPost(t, ts, "/v1/register", "", map[string]any{
			"handle":            h,
			"device_secret_b64": base64.StdEncoding.EncodeToString(secret),
		})
		if code != http.StatusBadRequest {
			t.Fatalf("handle %q expected 400; got %d", h, code)
		}
	}
}

func TestRegister_RejectsBadSecret(t *testing.T) {
	ts := newTestServer(t)
	defer ts.Close()
	code, _ := mustPost(t, ts, "/v1/register", "", map[string]any{
		"handle":            "alice",
		"device_secret_b64": "not-base64!!",
	})
	if code != http.StatusBadRequest {
		t.Fatalf("expected 400; got %d", code)
	}
	code, _ = mustPost(t, ts, "/v1/register", "", map[string]any{
		"handle":            "alice",
		"device_secret_b64": base64.StdEncoding.EncodeToString([]byte{1, 2, 3}),
	})
	if code != http.StatusBadRequest {
		t.Fatalf("expected 400 for short secret; got %d", code)
	}
}

func TestSnapshotPersistence(t *testing.T) {
	tmp, err := os.CreateTemp("", "velix-alpha-*.json")
	if err != nil {
		t.Fatal(err)
	}
	tmpPath := tmp.Name()
	tmp.Close()
	defer os.Remove(tmpPath)

	st := store.New()
	if err := st.CreateAccount(store.Account{
		ID: "id1", Handle: "alice", IdentityPub: []byte{1, 2, 3, 4},
	}); err != nil {
		t.Fatal(err)
	}
	if err := st.CreateAccount(store.Account{
		ID: "id2", Handle: "bob", IdentityPub: []byte{5, 6, 7, 8},
	}); err != nil {
		t.Fatal(err)
	}
	now := time.Now().UTC()
	conv := st.UpsertConversationFor("id1", "id2", "Hello", now, func() string { return "conv-1" })
	st.AppendMessage(store.Message{
		ID:             "m1",
		ConversationID: conv.ID,
		SenderID:       "id1",
		Kind:           "text",
		CiphertextB64:  "aGVsbG8=", // "hello"
		SentAt:         now,
	}, "hello")

	if err := st.Save(tmpPath); err != nil {
		t.Fatal(err)
	}

	st2 := store.New()
	if err := st2.Load(tmpPath); err != nil {
		t.Fatal(err)
	}
	a, ok := st2.GetAccount("id1")
	if !ok || a.Handle != "alice" {
		t.Fatalf("expected account to round-trip; got %+v ok=%v", a, ok)
	}
	gotConv, ok := st2.GetConversation(conv.ID)
	if !ok || gotConv.MemberA != "id1" || gotConv.MemberB != "id2" {
		t.Fatalf("expected conversation to round-trip; got %+v ok=%v", gotConv, ok)
	}
	msgs := st2.ListMessages(conv.ID)
	if len(msgs) != 1 || msgs[0].ID != "m1" || msgs[0].CiphertextB64 != "aGVsbG8=" {
		t.Fatalf("expected message to round-trip; got %+v", msgs)
	}
}

func TestOpenConversation_IsIdempotent(t *testing.T) {
	ts := newTestServer(t)
	defer ts.Close()

	secretA := freshSecret(t)
	secretB := freshSecret(t)

	// Register A and B.
	_, body := mustPost(t, ts, "/v1/register", "", map[string]any{
		"handle":            "alice",
		"device_secret_b64": base64.StdEncoding.EncodeToString(secretA),
	})
	var regA struct {
		AccountID string `json:"account_id"`
		Token     string `json:"token"`
	}
	_ = json.Unmarshal(body, &regA)

	_, body = mustPost(t, ts, "/v1/register", "", map[string]any{
		"handle":            "bob",
		"device_secret_b64": base64.StdEncoding.EncodeToString(secretB),
	})
	var regB struct {
		AccountID string `json:"account_id"`
		Token     string `json:"token"`
	}
	_ = json.Unmarshal(body, &regB)

	// A opens a conversation with B.
	_, body = mustPost(t, ts, "/v1/conversations", regA.Token, map[string]any{
		"peer_account_id": regB.AccountID,
		"title":           "from A",
	})
	var first struct {
		ID string `json:"id"`
	}
	_ = json.Unmarshal(body, &first)

	// A reopens with B → same id.
	_, body = mustPost(t, ts, "/v1/conversations", regA.Token, map[string]any{
		"peer_account_id": regB.AccountID,
		"title":           "from A again",
	})
	var second struct {
		ID string `json:"id"`
	}
	_ = json.Unmarshal(body, &second)
	if first.ID != second.ID {
		t.Fatalf("expected same conversation id from A; got %q vs %q", first.ID, second.ID)
	}

	// B opens with A (reversed order) → still same id.
	_, body = mustPost(t, ts, "/v1/conversations", regB.Token, map[string]any{
		"peer_account_id": regA.AccountID,
		"title":           "from B",
	})
	var third struct {
		ID string `json:"id"`
	}
	_ = json.Unmarshal(body, &third)
	if first.ID != third.ID {
		t.Fatalf("expected reversed-order open to return same id; got %q vs %q", first.ID, third.ID)
	}
}
