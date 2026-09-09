import { SquarePen, MessagesSquare, Send } from 'lucide-react';
import React, { useEffect, useRef, useState } from 'react';
import { fetchConversations, fetchConversationMessages, sendChatMessage } from '../../../services/chatApi';
import { API_ORIGIN } from '../../../services/authApi';

/**
 * The signed-in seller's numeric id.
 *
 * `/auth/login` returns it as `id` while `/user/me` returns it as `userId`,
 * and the session holds whichever the login stored. Reading only one of the
 * two is how this screen came to show the seller as their own chat partner:
 * "the participant who is not me" matched nobody, so it fell through to the
 * first participant, which is the seller.
 */
function myNumericId(user) {
  const raw = user?.userId ?? user?.id;
  const n = Number(raw);
  return Number.isFinite(n) && n > 0 ? n : null;
}

/** What a conversation row shows when the message is not words. */
function previewOf(message) {
  if (!message) return 'No messages yet';
  if (message.text) return message.text;
  if (message.kind === 'product') return `Shared ${message.product?.name || 'a product'}`;
  if (message.mediaUrl) return 'Sent a photo';
  return 'No messages yet';
}

export default function MessagesTab({ user }) {
  const [conversations, setConversations] = useState([]);
  const [selectedId, setSelectedId] = useState(null);
  const [messages, setMessages] = useState([]);
  const [msgInput, setMsgInput] = useState('');
  const [sending, setSending] = useState(false);
  const [newRecipientId, setNewRecipientId] = useState('');
  const [showNewChat, setShowNewChat] = useState(false);
  const [newChatError, setNewChatError] = useState('');
  const msgEndRef = useRef(null);

  const loadConversations = async () => {
    try {
      const res = await fetchConversations();
      setConversations(Array.isArray(res.data) ? res.data : []);
    } catch {
      setConversations([]);
    }
  };

  useEffect(() => {
    loadConversations();
    const interval = setInterval(loadConversations, 5000);
    return () => clearInterval(interval);
  }, []);

  const loadMessages = async (conversationId) => {
    try {
      const res = await fetchConversationMessages(conversationId);
      setMessages(Array.isArray(res.data) ? res.data : []);
    } catch {
      setMessages([]);
    }
  };

  useEffect(() => {
    if (!selectedId) return;
    loadMessages(selectedId);
    const interval = setInterval(() => loadMessages(selectedId), 4000);
    return () => clearInterval(interval);
  }, [selectedId]);

  useEffect(() => {
    msgEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const myUserId = myNumericId(user);

  /**
   * The person on the other end, or null.
   *
   * Null rather than falling back to the first participant: showing the seller
   * their own name is worse than showing nothing, because a reply then goes to
   * themselves.
   */
  function otherParticipant(convo) {
    if (!myUserId) return null;
    return convo.participants.find((p) => p.userId !== myUserId) || null;
  }

  async function handleSend() {
    if (!msgInput.trim()) return;
    const convo = conversations.find((c) => c._id === selectedId);
    const recipient = convo ? otherParticipant(convo) : null;
    if (!recipient) return;

    setSending(true);
    try {
      await sendChatMessage(recipient.userId, msgInput.trim());
      setMsgInput('');
      await loadMessages(selectedId);
      await loadConversations();
    } catch {
      // leave the input as-is so the seller can retry
    } finally {
      setSending(false);
    }
  }

  function handleMsgKey(e) {
    if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); handleSend(); }
  }

  async function handleStartNewChat(e) {
    e.preventDefault();
    setNewChatError('');
    const recipientId = Number(newRecipientId);
    if (!recipientId) {
      setNewChatError('Enter a valid numeric User ID.');
      return;
    }
    try {
      await sendChatMessage(recipientId, 'Hi! Reaching out about your order.');
      setNewRecipientId('');
      setShowNewChat(false);
      await loadConversations();
    } catch (err) {
      setNewChatError(err.response?.data?.message || 'Could not start this conversation.');
    }
  }

  const selectedConvo = conversations.find((c) => c._id === selectedId);
  const selectedOther = selectedConvo ? otherParticipant(selectedConvo) : null;

  return (
    <div className="ap-tab-content ap-chat-layout">
      <div className="ap-chat-sidebar">
        <div className="ap-chat-sidebar-header">
          <h3>Messages</h3>
          <button className="ap-icon-btn" type="button" onClick={() => setShowNewChat((s) => !s)} title="New message"><SquarePen size={15} strokeWidth={2.2} /></button>
        </div>
        {showNewChat && (
          <form className="ap-chat-new-form" onSubmit={handleStartNewChat}>
            {newChatError && <p className="ap-empty-state" style={{ padding: '0.5rem' }}>{newChatError}</p>}
            <input
              type="number"
              placeholder="Buyer's User ID"
              value={newRecipientId}
              onChange={(e) => setNewRecipientId(e.target.value)}
            />
            <button type="submit" className="ap-btn-primary">Start</button>
          </form>
        )}
        {conversations.length === 0 ? (
          <p className="ap-empty-state" style={{ padding: '1rem' }}>No conversations yet.</p>
        ) : (
          conversations.map((c) => {
            const other = otherParticipant(c);

            // Signed in with a session that predates the id fix. Saying so
            // beats listing a row that would reply to the seller themselves.
            if (!other) {
              return (
                <div key={c._id} className="ap-empty-state" style={{ padding: '0.75rem' }}>
                  Sign out and back in to load this conversation.
                </div>
              );
            }

            return (
              <button
                key={c._id}
                className={`ap-chat-user ${selectedId === c._id ? 'active' : ''}`}
                onClick={() => setSelectedId(c._id)}
              >
                <div className="ap-chat-avatar">{(other?.name || '?').slice(0, 2).toUpperCase()}</div>
                <div className="ap-chat-user-info">
                  <span className="ap-chat-user-name">{other?.name || 'Unknown'}</span>
                  <span className="ap-chat-user-last">{previewOf(c.lastMessage)}</span>
                </div>
                <div className="ap-chat-meta">
                  <span className="ap-chat-time">
                    {c.lastMessage ? new Date(c.lastMessage.createdAt).toLocaleTimeString('en-PH', { hour: '2-digit', minute: '2-digit' }) : ''}
                  </span>
                </div>
              </button>
            );
          })
        )}
      </div>

      <div className="ap-chat-main">
        {!selectedConvo ? (
          <div className="ap-chat-empty">
            <div className="ap-chat-empty-icon"><MessagesSquare size={30} strokeWidth={1.6} /></div>
            <p>Select a conversation to start messaging</p>
          </div>
        ) : (
          <>
            <div className="ap-chat-header">
              <div className="ap-chat-avatar">{(selectedOther?.name || '?').slice(0, 2).toUpperCase()}</div>
              <div>
                <div className="ap-chat-header-name">{selectedOther?.name}</div>
                <div className="ap-chat-header-status">{selectedOther?.role}</div>
              </div>
            </div>
            <div className="ap-chat-messages">
              {messages.map((m) => {
                // An order update is nobody's turn. It sits across the thread
                // rather than on one side of it.
                if (m.kind === 'system') {
                  return (
                    <div key={m._id} className="ap-msg-system">
                      <span>{m.text}</span>
                    </div>
                  );
                }

                const mine = m.sender?.userId === myUserId;

                return (
                  <div key={m._id} className={`ap-msg ${mine ? 'ap-msg-out' : 'ap-msg-in'}`}>
                    <div className="ap-msg-bubble">
                      {m.product && (
                        <div className="ap-msg-product">
                          <strong>{m.product.name}</strong>
                          <span>
                            ₱{Number(m.product.price || 0).toFixed(0)} per kg ·{' '}
                            {m.product.stock > 0 ? `${m.product.stock} kg left` : 'Out of stock'}
                          </span>
                        </div>
                      )}
                      {m.mediaUrl && (
                        // Chat photos live in the public media folder, not
                        // behind /api/files, so a plain img is enough. Saying
                        // "Photo attached" made the seller ask what it was.
                        <a
                          href={`${API_ORIGIN}${m.mediaUrl}`}
                          target="_blank"
                          rel="noreferrer"
                          className="ap-msg-photo"
                        >
                          <img src={`${API_ORIGIN}${m.mediaUrl}`} alt="Sent attachment" />
                        </a>
                      )}
                      {m.text}
                    </div>
                    <div className="ap-msg-time">{new Date(m.createdAt).toLocaleTimeString('en-PH', { hour: '2-digit', minute: '2-digit' })}</div>
                  </div>
                );
              })}
              <div ref={msgEndRef} />
            </div>
            <div className="ap-chat-input-row">
              <input
                className="ap-chat-input"
                type="text"
                placeholder="Type a message…"
                value={msgInput}
                onChange={(e) => setMsgInput(e.target.value)}
                onKeyDown={handleMsgKey}
              />
              <button className="ap-chat-send" onClick={handleSend} disabled={!msgInput.trim() || sending}>
                Send <Send size={14} strokeWidth={2.3} />
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
