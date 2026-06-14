// Nova Chat - Interactive behaviors

document.addEventListener('DOMContentLoaded', () => {
  initChat();
  initSidebar();
});

function initChat() {
  const input = document.querySelector('.chat-input input');
  const sendBtn = document.querySelector('.send-btn');
  const messagesContainer = document.querySelector('.chat-messages');

  function sendMessage() {
    const text = input.value.trim();
    if (!text) return;

    const messageRow = document.createElement('div');
    messageRow.className = 'message-row outgoing';

    const now = new Date();
    const time = now.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });

    messageRow.innerHTML = `
      <div class="message-content">
        <div class="message-bubble outgoing">${escapeHtml(text)}</div>
        <span class="message-time">${time}</span>
      </div>
    `;

    messagesContainer.appendChild(messageRow);
    input.value = '';
    messagesContainer.scrollTop = messagesContainer.scrollHeight;

    // Simulate typing indicator then reply
    setTimeout(() => {
      showTypingIndicator(messagesContainer);
    }, 800);

    setTimeout(() => {
      removeTypingIndicator(messagesContainer);
      addReply(messagesContainer);
    }, 2500);
  }

  sendBtn.addEventListener('click', sendMessage);
  input.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') sendMessage();
  });
}

function showTypingIndicator(container) {
  const typing = document.createElement('div');
  typing.className = 'message-row incoming typing-indicator';
  typing.innerHTML = `
    <div class="avatar avatar-sm" style="background: linear-gradient(135deg, #6366f1, #8b5cf6);">SC</div>
    <div class="message-content">
      <div class="message-bubble incoming">
        <span class="typing-dots">
          <span></span><span></span><span></span>
        </span>
      </div>
    </div>
  `;
  container.appendChild(typing);
  container.scrollTop = container.scrollHeight;
}

function removeTypingIndicator(container) {
  const indicator = container.querySelector('.typing-indicator');
  if (indicator) indicator.remove();
}

function addReply(container) {
  const replies = [
    "That sounds great! Let me check and get back to you.",
    "Sure thing! I'll have it ready by tomorrow 👍",
    "Interesting idea! Let's discuss this in our next standup.",
    "Love it! The team will be excited about this direction.",
    "Got it! I'll update the designs and share a new version.",
  ];

  const reply = replies[Math.floor(Math.random() * replies.length)];
  const now = new Date();
  const time = now.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });

  const messageRow = document.createElement('div');
  messageRow.className = 'message-row incoming';
  messageRow.innerHTML = `
    <div class="avatar avatar-sm" style="background: linear-gradient(135deg, #6366f1, #8b5cf6);">SC</div>
    <div class="message-content">
      <div class="message-bubble incoming">${reply}</div>
      <span class="message-time">${time}</span>
    </div>
  `;

  container.appendChild(messageRow);
  container.scrollTop = container.scrollHeight;
}

function initSidebar() {
  // DM item click - visual active state
  const dmItems = document.querySelectorAll('.dm-item');
  dmItems.forEach(item => {
    item.addEventListener('click', () => {
      dmItems.forEach(i => i.classList.remove('active'));
      item.classList.add('active');
    });
  });

  // Channel item click
  const channelItems = document.querySelectorAll('.channel-item');
  channelItems.forEach(item => {
    item.addEventListener('click', () => {
      channelItems.forEach(i => i.classList.remove('active'));
      item.classList.add('active');
    });
  });
}

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

// Add typing animation styles dynamically
const style = document.createElement('style');
style.textContent = `
  .typing-dots {
    display: inline-flex;
    gap: 4px;
    padding: 4px 0;
  }
  .typing-dots span {
    width: 7px;
    height: 7px;
    background: var(--text-muted);
    border-radius: 50%;
    animation: typing 1.4s infinite;
  }
  .typing-dots span:nth-child(2) { animation-delay: 0.2s; }
  .typing-dots span:nth-child(3) { animation-delay: 0.4s; }
  @keyframes typing {
    0%, 60%, 100% { opacity: 0.3; transform: translateY(0); }
    30% { opacity: 1; transform: translateY(-4px); }
  }
`;
document.head.appendChild(style);
