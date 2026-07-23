
        <div class="feature-card rounded-xl p-6">
          <div class="flex items-start gap-4">
            <div class="w-12 h-12 rounded-lg bg-blue-500/10 flex items-center justify-center flex-shrink-0">
              <span class="text-2xl">🚀</span>
            </div>
            <div>
              <h3 class="text-xl font-semibold text-white mb-2">crm-cli launches — v0.1</h3>
              <p class="text-white/40 leading-relaxed">The agent-first CRM: a single local-first binary over SQLite, JSON in/out, no UI. Contacts + an event timeline; a webhook sink (Resend) auto-logs opens, bounces, complaints, and replies with zero data entry.</p>
            </div>
          </div>
        </div>

        <div class="feature-card rounded-xl p-6">
          <div class="flex items-start gap-4">
            <div class="w-12 h-12 rounded-lg bg-emerald-500/10 flex items-center justify-center flex-shrink-0">
              <span class="text-2xl">📋</span>
            </div>
            <div>
              <h3 class="text-xl font-semibold text-white mb-2">Campaigns live in the CRM</h3>
              <p class="text-white/40 leading-relaxed">Stage a channel-routed campaign (<code>queue-bulk</code>) and read it back three ways — a digest, structured rows, or a send-ready JSONL — instead of juggling a scratch file. <code>followups</code> auto-selects who's due a second touch.</p>
            </div>
          </div>
        </div>

        <div class="feature-card rounded-xl p-6">
          <div class="flex items-start gap-4">
            <div class="w-12 h-12 rounded-lg bg-purple-500/10 flex items-center justify-center flex-shrink-0">
              <span class="text-2xl">📧</span>
            </div>
            <div>
              <h3 class="text-xl font-semibold text-white mb-2">Native send — email and calls</h3>
              <p class="text-white/40 leading-relaxed"><code>crm send</code> drip-sends cold email over SMTP; <code>crm call</code> drip-dials AI cold-calls over Bland. Both bring-your-own (Resend, Bland), both suppression-checked, both self-tracking via the webhook sink.</p>
            </div>
          </div>
        </div>

        <div class="feature-card rounded-xl p-6">
          <div class="flex items-start gap-4">
            <div class="w-12 h-12 rounded-lg bg-amber-500/10 flex items-center justify-center flex-shrink-0">
              <span class="text-2xl">📦</span>
            </div>
            <div>
              <h3 class="text-xl font-semibold text-white mb-2">One-line install, self-update</h3>
              <p class="text-white/40 leading-relaxed">A prebuilt binary — no compiler needed for most systems, with an automatic build-from-source fallback. <code>crm version</code> and <code>crm update</code> keep it current.</p>
            </div>
          </div>
        </div>

        <div class="feature-card rounded-xl p-6">
          <div class="flex items-start gap-4">
            <div class="w-12 h-12 rounded-lg bg-red-500/10 flex items-center justify-center flex-shrink-0">
              <span class="text-2xl">🛟</span>
            </div>
            <div>
              <h3 class="text-xl font-semibold text-white mb-2">Safety rails: dry-run and undo</h3>
              <p class="text-white/40 leading-relaxed">Preview a send or a call batch with <code>--dry-run</code> — no creds, no network, no writes. Made a mistake staging, staging a follow-up, or suppressing? <code>crm undo</code> reverts it, LIFO, backed by a real audit trail.</p>
            </div>
          </div>
        </div>

        <div class="feature-card rounded-xl p-6">
          <div class="flex items-start gap-4">
            <div class="w-12 h-12 rounded-lg bg-teal-500/10 flex items-center justify-center flex-shrink-0">
              <span class="text-2xl">🔗</span>
            </div>
            <div>
              <h3 class="text-xl font-semibold text-white mb-2">Find and merge duplicate contacts</h3>
              <p class="text-white/40 leading-relaxed"><code>crm dedup</code> finds likely duplicates from formatting differences (case, phone punctuation) that exact-match misses. <code>crm merge</code> combines them, and <code>crm dedup --auto</code> runs the safe merges automatically — leaving ambiguous name-only matches for a human to judge.</p>
            </div>
          </div>
        </div>

        <div class="feature-card rounded-xl p-6">
          <div class="flex items-start gap-4">
            <div class="w-12 h-12 rounded-lg bg-sky-500/10 flex items-center justify-center flex-shrink-0">
              <span class="text-2xl">✅</span>
            </div>
            <div>
              <h3 class="text-xl font-semibold text-white mb-2">A real test suite, and a release gate</h3>
              <p class="text-white/40 leading-relaxed">149 automated checks (unit + integration) now guard every command's business rules. Releases run through a gate that refuses to ship if the suite is red.</p>
            </div>
          </div>
        </div>

        <div class="feature-card rounded-xl p-6">
          <div class="flex items-start gap-4">
            <div class="w-12 h-12 rounded-lg bg-indigo-500/10 flex items-center justify-center flex-shrink-0">
              <span class="text-2xl">🗂️</span>
            </div>
            <div>
              <h3 class="text-xl font-semibold text-white mb-2">Workspaces — multiple isolated CRMs, one binary</h3>
              <p class="text-white/40 leading-relaxed"><code>crm --workspace &lt;slug&gt;</code> gives each project or client its own SQLite DB. The <code>/sink</code> webhook accepts a <code>workspace</code> field so outreach drivers route touches to the right DB automatically. One binary, zero config files.</p>
            </div>
          </div>
        </div>

        <div class="feature-card rounded-xl p-6">
          <div class="flex items-start gap-4">
            <div class="w-12 h-12 rounded-lg bg-rose-500/10 flex items-center justify-center flex-shrink-0">
              <span class="text-2xl">📬</span>
            </div>
            <div>
              <h3 class="text-xl font-semibold text-white mb-2">Inbound reply archive — <code>crm inbound</code></h3>
              <p class="text-white/40 leading-relaxed">Full Resend reply bodies are now persisted in the CRM's <code>inbound_mail</code> table, keyed by <code>resend_id</code> for idempotency. Resend keeps them 30 days; the CRM keeps them indefinitely. Read them back with <code>crm inbound &lt;contact&gt;</code>.</p>
            </div>
          </div>
        </div>

        <div class="feature-card rounded-xl p-6">
          <div class="flex items-start gap-4">
            <div class="w-12 h-12 rounded-lg bg-lime-500/10 flex items-center justify-center flex-shrink-0">
              <span class="text-2xl">🧹</span>
            </div>
            <div>
              <h3 class="text-xl font-semibold text-white mb-2">Retention — <code>crm cleanup</code></h3>
              <p class="text-white/40 leading-relaxed">Stage-aware retention with <code>--dry-run</code>: purges old <code>audit</code>, <code>events</code>, <code>inbound_mail</code>, and <code>outreach</code> rows, but never touches active-pipeline contacts or the suppress list. Per-table env knobs with a global fallback.</p>
            </div>
          </div>
        </div>
