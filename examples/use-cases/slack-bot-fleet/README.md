# Use Case: Multi-Agent Slack Bot Fleet

Deploy multiple specialized Slack bots as Symbiont agents. Each bot handles a different domain (support, status, alerts) with isolated capabilities and audit logging.

## Architecture

```
Slack ──► Cloudflare Tunnel ──► Symbi Coordinator
                                    │
                              ┌─────┴─────┐
                              │            │
                         support_bot  status_bot
```

## Setup

1. Create a Slack app at https://api.slack.com/apps
2. Add bot scopes: `app_mentions:read`, `chat:write`
3. Set environment variables in `.env`:

```bash
SLACK_BOT_TOKEN=xoxb-your-bot-token
SLACK_SIGNING_SECRET=your-signing-secret
```

4. Copy the agent DSL:

```bash
cp examples/use-cases/slack-bot-fleet/agents/support_bot.dsl desktop/agents/
```

5. Restart the stack:

```bash
make desktop-down && make desktop-up
```

6. Set up Event Subscriptions in Slack to point to your Cloudflare Tunnel URL:
   `https://agents.yourdomain.com/webhook`

## Agents

- **support_bot.dsl**: Handles customer support questions with canned responses and escalation
- **chat_responder.dsl** (built-in): General chat and status reporting
