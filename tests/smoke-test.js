#!/usr/bin/env node
// smoke-test.js — AI-Gateway smoke gate
//
// 核心流量路径: client → LiteLLM(:4000) → copilot-api(:4141) → Copilot Pro
//
// 阶段 1: 服务健康（端口 LISTENING）
// 阶段 2: 鉴权（无 master_key 必须被拒）
// 阶段 3: 核心流量
//   3.1 Anthropic 协议非流式 (Claude Code 主路径)
//   3.2 Anthropic 协议 streaming SSE
//   3.3 OpenAI 协议非流式 (Cursor 主路径)
// 阶段 4: 条件检查 — admin UI（仅当 .env 有 DATABASE_URL 时跑）
//   4.1 /health/readiness 200 + DB connected
//   4.2 /ui 200
// 阶段 5: 条件检查 — cost.html 静态结构（仅当 web/cost.html 存在时跑）
//   5.1 含 Chart.js CDN 引用
//   5.2 引用 /spend/logs endpoint
//
// Usage: node tests/smoke-test.js
// 退出码: 0 = PASS, 1 = FAIL

'use strict';

const { execSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.resolve(__dirname, '..');
const HOST = '127.0.0.1';
const LITELLM_PORT = 4000;
const COPILOT_PORT = 4141;
const BASE = `http://${HOST}:${LITELLM_PORT}`;

function loadEnvVar(name) {
    if (process.env[name]) return process.env[name];
    const envFile = path.join(ROOT, '.env');
    if (!fs.existsSync(envFile)) return null;
    const re = new RegExp(`^${name}\\s*=\\s*(.+)$`);
    for (const line of fs.readFileSync(envFile, 'utf8').split(/\r?\n/)) {
        const m = line.match(re);
        if (m) return m[1].trim().replace(/^['"]|['"]$/g, '');
    }
    return null;
}

const MASTER_KEY = loadEnvVar('LITELLM_MASTER_KEY');
const DATABASE_URL = loadEnvVar('DATABASE_URL');

// ============================================================================
// 阶段 1: 服务健康
// ============================================================================
function checkPortListening() {
    console.log('=== 阶段 1: 服务健康 ===');
    let netstat;
    try {
        netstat = execSync('netstat -ano', { encoding: 'utf8' });
    } catch (e) {
        console.error('  ERR: netstat 失败:', e.message);
        return false;
    }
    let ok = true;
    for (const [name, port] of [['LiteLLM', LITELLM_PORT], ['copilot-api', COPILOT_PORT]]) {
        const re = new RegExp(`:${port}\\s+\\S+\\s+LISTENING`);
        if (re.test(netstat)) {
            console.log(`  PASS ${name} :${port} LISTENING`);
        } else {
            console.error(`  FAIL ${name} :${port} 未监听（先跑 scripts\\start-all.ps1）`);
            ok = false;
        }
    }
    return ok;
}

// ============================================================================
// 阶段 2: 鉴权
// ============================================================================
async function checkAuthRejection() {
    console.log('=== 阶段 2: 鉴权 ===');
    let res;
    try {
        res = await fetch(`${BASE}/v1/messages`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'anthropic-version': '2023-06-01',
            },
            body: JSON.stringify({
                model: 'claude-sonnet-4-6-copilot',
                max_tokens: 5,
                messages: [{ role: 'user', content: 'x' }],
            }),
        });
    } catch (e) {
        console.error('  FAIL 请求异常:', e.message);
        return false;
    }
    if (res.status === 401 || res.status === 403) {
        console.log(`  PASS 无 master_key → ${res.status}`);
        return true;
    }
    const body = await res.text();
    console.error(`  FAIL 无 master_key 期望 401/403, 实得 ${res.status}: ${body.substring(0, 200)}`);
    return false;
}

// ============================================================================
// 阶段 3: 核心流量
// ============================================================================
async function checkAnthropicNonStream() {
    const model = 'claude-opus-4-7-copilot';
    let res;
    try {
        res = await fetch(`${BASE}/v1/messages`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'x-api-key': MASTER_KEY,
                'anthropic-version': '2023-06-01',
            },
            body: JSON.stringify({
                model,
                max_tokens: 30,
                messages: [{ role: 'user', content: 'Reply with exactly: OK' }],
            }),
        });
    } catch (e) {
        console.error(`  FAIL ${model} 请求异常:`, e.message);
        return false;
    }
    if (res.status !== 200) {
        const body = await res.text();
        console.error(`  FAIL ${model} 状态码 ${res.status}: ${body.substring(0, 200)}`);
        return false;
    }
    const j = await res.json();
    const text = j?.content?.[0]?.text;
    if (j.model && text) {
        console.log(`  PASS ${model} → "${text.trim().substring(0, 30)}"`);
        return true;
    }
    console.error(`  FAIL ${model} 响应结构错: ${JSON.stringify(j).substring(0, 200)}`);
    return false;
}

async function checkAnthropicStreaming() {
    const model = 'claude-sonnet-4-6-copilot';
    let res;
    try {
        res = await fetch(`${BASE}/v1/messages`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'x-api-key': MASTER_KEY,
                'anthropic-version': '2023-06-01',
            },
            body: JSON.stringify({
                model,
                max_tokens: 50,
                stream: true,
                messages: [{ role: 'user', content: 'Say: hi' }],
            }),
        });
    } catch (e) {
        console.error(`  FAIL ${model} stream 请求异常:`, e.message);
        return false;
    }
    if (res.status !== 200) {
        const body = await res.text();
        console.error(`  FAIL ${model} stream 状态码 ${res.status}: ${body.substring(0, 200)}`);
        return false;
    }
    const text = await res.text();
    const required = [
        'message_start',
        'content_block_start',
        'content_block_delta',
        'content_block_stop',
        'message_delta',
        'message_stop',
    ];
    const missing = required.filter(t => !text.includes(`event: ${t}`));
    if (missing.length === 0) {
        console.log(`  PASS ${model} stream → 6 类 SSE event 齐`);
        return true;
    }
    console.error(`  FAIL ${model} stream 缺 event: ${missing.join(', ')}`);
    return false;
}

async function checkOpenAICompletions() {
    const model = 'copilot/claude-sonnet-4.6';
    let res;
    try {
        res = await fetch(`${BASE}/v1/chat/completions`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${MASTER_KEY}`,
            },
            body: JSON.stringify({
                model,
                max_tokens: 30,
                messages: [{ role: 'user', content: 'Reply with exactly: OK' }],
            }),
        });
    } catch (e) {
        console.error(`  FAIL ${model} 请求异常:`, e.message);
        return false;
    }
    if (res.status !== 200) {
        const body = await res.text();
        console.error(`  FAIL ${model} 状态码 ${res.status}: ${body.substring(0, 200)}`);
        return false;
    }
    const j = await res.json();
    const text = j?.choices?.[0]?.message?.content;
    if (text) {
        console.log(`  PASS ${model} → "${text.trim().substring(0, 30)}"`);
        return true;
    }
    console.error(`  FAIL ${model} 响应结构错: ${JSON.stringify(j).substring(0, 200)}`);
    return false;
}

async function checkCoreTraffic() {
    console.log('=== 阶段 3: 核心流量 ===');
    if (!MASTER_KEY) {
        console.error('  ERR: 无 LITELLM_MASTER_KEY (env / .env 都没)');
        return false;
    }
    const r1 = await checkAnthropicNonStream();
    const r2 = await checkAnthropicStreaming();
    const r3 = await checkOpenAICompletions();
    return r1 && r2 && r3;
}

// ============================================================================
// 阶段 4: admin UI（条件 — 仅当 DATABASE_URL 配置）
// ============================================================================
async function checkAdminUI() {
    console.log('=== 阶段 4: admin UI（条件） ===');
    if (!DATABASE_URL) {
        console.log('  SKIP: DATABASE_URL 未配置（M1.5 Postgres 未上）');
        return true;
    }
    let ok = true;

    // 4.1 readiness
    try {
        const r = await fetch(`${BASE}/health/readiness`);
        if (r.status === 200) {
            console.log('  PASS /health/readiness 200');
        } else {
            console.error(`  FAIL /health/readiness ${r.status}`);
            ok = false;
        }
    } catch (e) {
        console.error('  FAIL /health/readiness 异常:', e.message);
        ok = false;
    }

    // 4.2 admin UI assets
    try {
        const r = await fetch(`${BASE}/ui`, { redirect: 'manual' });
        // /ui 通常是 SPA 入口，可能 200 (StaticFiles 直 index.html) 或 307/308 重定向
        if (r.status === 200 || (r.status >= 300 && r.status < 400)) {
            console.log(`  PASS /ui ${r.status}`);
        } else {
            console.error(`  FAIL /ui ${r.status}`);
            ok = false;
        }
    } catch (e) {
        console.error('  FAIL /ui 异常:', e.message);
        ok = false;
    }
    return ok;
}

// ============================================================================
// 阶段 5: cost.html 静态结构（条件 — 仅当 web/cost.html 存在）
// ============================================================================
function checkCostPage() {
    console.log('=== 阶段 5: cost.html 静态结构（条件） ===');
    const f = path.join(ROOT, 'web', 'cost.html');
    if (!fs.existsSync(f)) {
        console.log('  SKIP: web/cost.html 不存在');
        return true;
    }
    const html = fs.readFileSync(f, 'utf8');
    let ok = true;
    if (html.toLowerCase().includes('chart.js')) {
        console.log('  PASS web/cost.html 含 Chart.js CDN 引用');
    } else {
        console.error('  FAIL web/cost.html 缺 Chart.js');
        ok = false;
    }
    if (html.includes('/spend/logs')) {
        console.log('  PASS web/cost.html 引用 /spend/logs endpoint');
    } else {
        console.error('  FAIL web/cost.html 不调 /spend/logs');
        ok = false;
    }
    return ok;
}

// ============================================================================
// Main
// ============================================================================
(async () => {
    const results = [];
    results.push(checkPortListening());
    results.push(await checkAuthRejection());
    results.push(await checkCoreTraffic());
    results.push(await checkAdminUI());
    results.push(checkCostPage());

    const allPass = results.every(Boolean);
    console.log('');
    console.log(allPass ? 'SMOKE: PASS' : 'SMOKE: FAIL');
    process.exit(allPass ? 0 : 1);
})();
