<script setup lang="ts">
import type { EChartsOption } from 'echarts';

interface ChartItem {
  title: string;
  sql: string;
  data: Record<string, unknown>[];
  option: EChartsOption;
}

interface ChartResponse {
  charts: ChartItem[];
}

interface ChartSuggestion {
  title: string;
  prompt: string;
  chartType: string;
  rationale: string;
}

const prompt = ref('');
const chartResult = ref<ChartResponse | null>(null);
const examples = ref<ChartSuggestion[]>([]);
const isLoadingExamples = ref(false);
const examplesError = ref('');
const isLoading = ref(false);
const errorMessage = ref('');

async function generateChart() {
  const request = prompt.value.trim();
  if (!request || isLoading.value) {
    return;
  }

  isLoading.value = true;
  errorMessage.value = '';

  try {
    chartResult.value = await $fetch<ChartResponse>('/api/chart', {
      method: 'POST',
      body: { prompt: request },
    });
  } catch (error) {
    chartResult.value = null;
    const fetchError = error as {
      data?: { statusMessage?: string; message?: string };
      statusMessage?: string;
      message?: string;
    };
    errorMessage.value = fetchError.data?.statusMessage
      ?? fetchError.statusMessage
      ?? fetchError.data?.message
      ?? fetchError.message
      ?? '生成图表时发生错误，请稍后重试。';
  } finally {
    isLoading.value = false;
  }
}

function useExample(example: string) {
  prompt.value = example;
  errorMessage.value = '';
}

async function loadSuggestions() {
  isLoadingExamples.value = true;
  examplesError.value = '';

  try {
    const result = await $fetch<{ suggestions: ChartSuggestion[] }>('/api/chart/suggestions');
    examples.value = result.suggestions;
  } catch {
    examplesError.value = '暂时无法加载推荐问题，请直接输入你想分析的内容。';
  } finally {
    isLoadingExamples.value = false;
  }
}

onMounted(() => {
  void loadSuggestions();
});

</script>

<template>
  <div class="workspace">
    <main class="main-content">
      <div class="page-body">
        <section class="intro">
          <div class="eyebrow"><span class="sparkle">✳</span> 自然语言 · 实时数据</div>
          <h1>
            <a class="brand" href="/" aria-label="ChartPilot 首页">
              <span class="brand-name">Chart<span>Pilot</span></span>
            </a>
            让数据，<span>开口说话。</span></h1>
          <p class="intro-copy">描述你想了解的业务问题，AI 会查询真实数据并为你生成图表。</p>
        </section>

        <section class="prompt-panel" aria-labelledby="prompt-heading">
          <div class="prompt-panel-top">
            <div class="prompt-heading-wrap">
              <span class="prompt-icon">
                <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
                  <path d="M12 3.5 13.9 9l5.6 1.9-5.6 1.9-1.9 5.7-1.9-5.7-5.6-1.9L10.1 9 12 3.5Z" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round" />
                  <path d="m19 15 .9 2.1L22 18l-2.1.9L19 21l-.9-2.1L16 18l2.1-.9L19 15Z" fill="currentColor" />
                </svg>
              </span>
              <div>
                <h2 id="prompt-heading">你想从数据中了解什么？</h2>
                <p>用自然语言提问，图表即刻生成</p>
              </div>
            </div>
            <span class="model-badge"><i /> DeepSeek</span>
          </div>

          <form class="prompt-form" @submit.prevent="generateChart">
            <label class="sr-only" for="chart-prompt">描述你想生成的图表</label>
            <textarea
              id="chart-prompt"
              v-model="prompt"
              maxlength="2000"
              rows="3"
              :disabled="isLoading"
              placeholder="例如：对比最近 12 个月每个产品的销售额，并按月份展示趋势..."
              @keydown.meta.enter.prevent="generateChart"
              @keydown.ctrl.enter.prevent="generateChart"
            />
            <div class="prompt-form-bottom">
              <span class="input-hint">
                <kbd>⌘</kbd><span>+</span><kbd>↵</kbd> 快速生成
                <span class="char-count">{{ prompt.length }}/2000</span>
              </span>
              <button class="generate-button" type="submit" :disabled="isLoading || !prompt.trim()">
                <template v-if="isLoading">
                  <span class="spinner" />
                  正在分析数据
                </template>
                <template v-else>
                  生成图表
                  <svg viewBox="0 0 20 20" fill="none" aria-hidden="true">
                    <path d="M4 10h12m-5-5 5 5-5 5" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" />
                  </svg>
                </template>
              </button>
            </div>
          </form>

          <div v-if="examples.length || isLoadingExamples || examplesError" class="examples">
            <span class="examples-label">试试这样问</span>
            <span v-if="isLoadingExamples" class="suggestions-hint">正在根据数据表生成建议…</span>
            <span v-else-if="examplesError" class="suggestions-hint">{{ examplesError }}</span>
            <button
              v-for="example in examples"
              :key="example.prompt"
              class="example-chip"
              type="button"
              :disabled="isLoading"
              :title="`${example.title} · ${example.rationale}`"
              @click="useExample(example.prompt)"
            >
              {{ example.prompt }}
            </button>
          </div>
          <p v-if="errorMessage" class="error-message" role="alert">
            <svg viewBox="0 0 20 20" fill="none" aria-hidden="true">
              <circle cx="10" cy="10" r="7.5" stroke="currentColor" stroke-width="1.5" />
              <path d="M10 6.5v4m0 3h.01" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" />
            </svg>
            {{ errorMessage }}
          </p>
        </section>

        <section v-if="chartResult" class="result-section" aria-live="polite">
          <div class="result-heading">
            <div>
              <div class="result-eyebrow"><span /> 查询结果</div>
              <h2>{{ chartResult.charts.length }} 张图表</h2>
            </div>
            <div class="result-meta">
              <span class="row-count">图表配置由 AI 生成</span>
            </div>
          </div>

          <article v-for="(chart, chartIndex) in chartResult.charts" :key="chartIndex" class="chart-result-card">
            <div class="chart-card-heading">
              <h3>{{ chart.title }}</h3>
              <span class="row-count">{{ chart.data.length }} 条数据</span>
            </div>
            <div class="chart-card">
              <EChartCanvas :option="chart.option" :aria-label="chart.title" />
              <div v-if="chart.data.length === 0" class="empty-chart">
                <span>查询成功，但没有符合条件的数据</span>
              </div>
            </div>

            <details class="data-details">
              <summary>
                <span class="details-leading">
                  <svg viewBox="0 0 20 20" fill="none" aria-hidden="true">
                    <path d="M3.5 4.5h13v11h-13zM3.5 8h13M8 8v7.5m4-7.5v7.5" stroke="currentColor" stroke-width="1.4" stroke-linejoin="round" />
                  </svg>
                  查看真实数据
                </span>
                <span class="details-count">{{ chart.data.length }} 行</span>
              </summary>
              <div class="table-wrap">
                <table v-if="chart.data.length">
                  <thead>
                    <tr>
                      <th v-for="column in Object.keys(chart.data[0]!)" :key="column">{{ column }}</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="(row, rowIndex) in chart.data" :key="rowIndex">
                      <td v-for="column in Object.keys(chart.data[0]!)" :key="column">
                        {{ row[column] === null ? '—' : String(row[column]) }}
                      </td>
                    </tr>
                  </tbody>
                </table>
                <p v-else class="no-rows">暂无数据行</p>
              </div>
            </details>

            <details class="data-details sql-details">
              <summary>
                <span class="details-leading">
                  <svg viewBox="0 0 20 20" fill="none" aria-hidden="true">
                    <path d="m7 5-5 5 5 5m6-10 5 5-5 5m-2-12-2 14" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round" />
                  </svg>
                  查看生成的 SQL
                </span>
                <span class="details-count">只读查询</span>
              </summary>
              <pre><code>{{ chart.sql }}</code></pre>
            </details>
          </article>
        </section>

        <section v-else-if="!isLoading && !errorMessage" class="welcome-card">
          <div class="welcome-illustration" aria-hidden="true">
            <div class="illustration-glow" />
            <div class="illustration-chart">
              <div class="chart-grid-line line-one" />
              <div class="chart-grid-line line-two" />
              <div class="chart-grid-line line-three" />
              <div class="bar bar-one" />
              <div class="bar bar-two" />
              <div class="bar bar-three" />
              <div class="bar bar-four" />
              <div class="bar bar-five" />
              <svg class="chart-trend" viewBox="0 0 220 82" fill="none">
                <path d="m7 64 48-25 43 14 48-37 66-8" stroke="#9183F5" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" />
                <circle cx="55" cy="39" r="4" fill="#fff" stroke="#9183F5" stroke-width="2.5" />
                <circle cx="98" cy="53" r="4" fill="#fff" stroke="#9183F5" stroke-width="2.5" />
                <circle cx="146" cy="16" r="4" fill="#fff" stroke="#9183F5" stroke-width="2.5" />
                <circle cx="212" cy="8" r="4" fill="#fff" stroke="#9183F5" stroke-width="2.5" />
              </svg>
            </div>
            <span class="floating-sparkle sparkle-one">✳</span>
            <span class="floating-sparkle sparkle-two">✦</span>
          </div>
          <h2>你的下一张图表，从一个问题开始</h2>
          <p>连接真实业务数据，用一句话发现数据背后的答案。</p>
        </section>

        <footer class="page-footer">
          <span><i /> 数据通过安全只读连接查询</span>
          <span>ChartPilot <b>·</b> AI 数据探索</span>
        </footer>
      </div>
    </main>
  </div>
</template>

<style>
:root {
  font-family: Inter, ui-sans-serif, -apple-system, BlinkMacSystemFont, "Segoe UI", "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", sans-serif;
  color: #202139;
  background: #f7f8fc;
  font-synthesis: none;
  text-rendering: optimizeLegibility;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

* {
  box-sizing: border-box;
}

body {
  min-width: 360px;
  min-height: 100vh;
  margin: 0;
}

button,
textarea {
  font: inherit;
}

button {
  cursor: pointer;
}

.workspace {
  min-height: 100vh;
}

.sidebar {
  position: fixed;
  z-index: 2;
  inset: 0 auto 0 0;
  display: flex;
  width: 248px;
  flex-direction: column;
  padding: 27px 17px 20px;
  border-right: 1px solid #ececf3;
  background: #fff;
}

.brand {
  display: inline-flex;
  width: fit-content;
  align-items: center;
  gap: 10px;
  margin: 0 0 51px 8px;
  color: #202139;
  text-decoration: none;
}

.brand-mark {
  display: grid;
  width: 36px;
  height: 36px;
  place-items: center;
  border-radius: 11px;
  background: linear-gradient(145deg, #8877f3, #6957df);
  box-shadow: 0 5px 12px #7060dc38;
  color: white;
}

.brand-mark svg {
  width: 25px;
  height: 25px;
}

.brand-name {
  font-size: 40px;
  font-weight: 750;
  letter-spacing: -0.7px;
}

.brand-name span {
  color: #7768e5;
}

.sidebar-label {
  padding: 0 12px;
  color: #a0a1b2;
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 1.1px;
  text-transform: uppercase;
}

.side-nav {
  display: grid;
  gap: 6px;
  margin-top: 13px;
}

.nav-item {
  display: flex;
  min-height: 44px;
  align-items: center;
  gap: 12px;
  padding: 0 12px;
  border-radius: 9px;
  color: #77798e;
  font-size: 12px;
  font-weight: 550;
  text-decoration: none;
}

.nav-item svg {
  width: 18px;
  height: 18px;
  flex: 0 0 auto;
}

.nav-item.active {
  background: #f1efff;
  color: #6959db;
  font-weight: 650;
}

.nav-dot {
  width: 6px;
  height: 6px;
  margin-left: auto;
  border-radius: 50%;
  background: #7667e7;
}

.nav-item.disabled {
  cursor: default;
  opacity: 0.7;
}

.soon-label {
  margin-left: auto;
  color: #a0a1b2;
  font-size: 9px;
}

.sidebar-bottom {
  margin-top: auto;
}

.connection-card {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 12px 10px;
  border: 1px solid #ededf4;
  border-radius: 11px;
  background: #fcfcfe;
}

.connection-icon {
  display: grid;
  width: 33px;
  height: 33px;
  flex: 0 0 auto;
  place-items: center;
  border-radius: 9px;
  background: #eff8f3;
  color: #43a574;
}

.connection-icon svg {
  width: 19px;
  height: 19px;
}

.connection-copy {
  display: grid;
  gap: 4px;
}

.connection-title {
  color: #3b3c53;
  font-size: 11px;
  font-weight: 650;
}

.connection-status {
  display: flex;
  align-items: center;
  gap: 5px;
  color: #87899b;
  font-size: 10px;
}

.connection-status i,
.page-footer i {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #4abb83;
  box-shadow: 0 0 0 3px #4abb8318;
}

.connection-chevron {
  width: 14px;
  height: 14px;
  margin-left: auto;
  color: #a5a6b6;
}

.sidebar-footnote {
  margin-top: 17px;
  color: #aaabba;
  font-size: 10px;
  text-align: center;
}

.main-content {
  min-height: 100vh;
}

.topbar {
  display: flex;
  height: 67px;
  align-items: center;
  justify-content: space-between;
  padding: 0 47px;
  border-bottom: 1px solid #ececf3;
  background: #ffffffd9;
}

.breadcrumb,
.topbar-right,
.secure-label {
  display: flex;
  align-items: center;
}

.breadcrumb {
  gap: 10px;
  color: #a0a1b0;
  font-size: 11px;
}

.breadcrumb svg {
  width: 12px;
  height: 12px;
  color: #c0c0cb;
}

.breadcrumb strong {
  color: #494a60;
  font-weight: 650;
}

.topbar-right {
  gap: 18px;
}

.secure-label {
  gap: 6px;
  color: #7e8192;
  font-size: 10px;
}

.secure-label svg {
  width: 14px;
  height: 14px;
  color: #48a978;
}

.avatar {
  display: grid;
  width: 29px;
  height: 29px;
  place-items: center;
  border: 2px solid white;
  border-radius: 50%;
  background: linear-gradient(145deg, #e1dcff, #c9c1ff);
  box-shadow: 0 0 0 1px #e8e6f2;
  color: #685bd0;
  font-size: 11px;
  font-weight: 700;
}

.page-body {
  width: min(100%, 1096px);
  margin: 0 auto;
  padding: 62px 52px 27px;
}

.intro {
  margin-bottom: 29px;
  text-align: center;
}

.eyebrow {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  margin-bottom: 15px;
  color: #7a6ce0;
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.55px;
}

.sparkle {
  font-size: 13px;
}

.intro h1 {
  margin: 0;
  color: #22233a;
  font-size: clamp(32px, 3.5vw, 43px);
  font-weight: 750;
  letter-spacing: -2px;
  line-height: 1.2;
}

.intro h1 span {
  background: linear-gradient(100deg, #7869e8 8%, #9a72df 90%);
  background-clip: text;
  -webkit-text-fill-color: transparent;
}

.intro-copy {
  margin: 13px 0 0;
  color: #85879a;
  font-size: 13px;
  letter-spacing: 0.05px;
}

.prompt-panel {
  padding: 21px 22px 16px;
  border: 1px solid #e9e8f1;
  border-radius: 15px;
  background: #fff;
  box-shadow: 0 10px 30px #31315408, 0 2px 5px #31315404;
}

.prompt-panel-top,
.prompt-heading-wrap,
.prompt-form-bottom,
.input-hint,
.examples,
.result-heading,
.result-meta,
.details-leading {
  display: flex;
  align-items: center;
}

.prompt-panel-top {
  justify-content: space-between;
  margin-bottom: 16px;
}

.prompt-heading-wrap {
  gap: 11px;
}

.prompt-icon {
  display: grid;
  width: 36px;
  height: 36px;
  place-items: center;
  border: 1px solid #eeebff;
  border-radius: 10px;
  background: #f7f5ff;
  color: #7768e7;
}

.prompt-icon svg {
  width: 21px;
  height: 21px;
}

.prompt-heading-wrap h2 {
  margin: 0;
  color: #33344b;
  font-size: 13px;
  font-weight: 680;
}

.prompt-heading-wrap p {
  margin: 4px 0 0;
  color: #9a9bad;
  font-size: 10px;
}

.model-badge {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px 9px;
  border: 1px solid #eeedf5;
  border-radius: 20px;
  color: #68697e;
  font-size: 10px;
  font-weight: 600;
}

.model-badge i {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #7667e7;
  box-shadow: 0 0 0 3px #7667e71c;
}

.prompt-form {
  padding: 13px 14px 10px;
  border: 1px solid #deddeb;
  border-radius: 10px;
  background: #fdfdff;
  transition: border-color 150ms ease, box-shadow 150ms ease;
}

.prompt-form:focus-within {
  border-color: #a69bf0;
  box-shadow: 0 0 0 3px #8171e713;
}

.prompt-form textarea {
  display: block;
  width: 100%;
  min-height: 65px;
  resize: vertical;
  border: 0;
  outline: 0;
  background: transparent;
  color: #33344b;
  font-size: 12px;
  line-height: 1.7;
}

.prompt-form textarea::placeholder {
  color: #b2b3c0;
}

.prompt-form textarea:disabled {
  cursor: wait;
}

.prompt-form-bottom {
  justify-content: space-between;
  gap: 14px;
  padding-top: 8px;
  border-top: 1px solid #f0eff5;
}

.input-hint {
  gap: 5px;
  color: #a4a5b3;
  font-size: 9px;
}

kbd {
  display: inline-grid;
  min-width: 16px;
  height: 17px;
  place-items: center;
  padding: 0 4px;
  border: 1px solid #e8e7ef;
  border-radius: 4px;
  background: #fff;
  color: #868799;
  font-family: inherit;
  font-size: 9px;
}

.char-count {
  margin-left: 5px;
  color: #b2b3c0;
}

.generate-button {
  display: inline-flex;
  min-height: 34px;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 0 13px;
  border: 0;
  border-radius: 7px;
  background: linear-gradient(110deg, #7869e8, #6d5cdb);
  box-shadow: 0 3px 8px #7667e72b;
  color: white;
  font-size: 10px;
  font-weight: 650;
  transition: opacity 150ms ease, transform 150ms ease, box-shadow 150ms ease;
}

.generate-button:hover:not(:disabled) {
  transform: translateY(-1px);
  box-shadow: 0 5px 12px #7667e73d;
}

.generate-button:disabled {
  cursor: not-allowed;
  opacity: 0.56;
}

.generate-button svg {
  width: 15px;
  height: 15px;
}

.spinner {
  width: 12px;
  height: 12px;
  border: 1.5px solid #ffffff66;
  border-top-color: white;
  border-radius: 50%;
  animation: spin 700ms linear infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

.examples {
  flex-wrap: wrap;
  gap: 7px;
  margin-top: 13px;
}

.examples-label {
  margin-right: 2px;
  color: #a0a1af;
  font-size: 9px;
}

.suggestions-hint {
  color: #9698a8;
  font-size: 9px;
  line-height: 1.5;
}

.example-chip {
  min-height: 25px;
  padding: 0 9px;
  border: 1px solid #edecf3;
  border-radius: 6px;
  background: #fff;
  color: #74768a;
  font-size: 9px;
  transition: border-color 120ms ease, background 120ms ease, color 120ms ease;
}

.example-chip:hover:not(:disabled) {
  border-color: #d6d0ff;
  background: #faf9ff;
  color: #6d5edc;
}

.example-chip:disabled {
  cursor: not-allowed;
  opacity: 0.6;
}

.error-message {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  margin: 13px 0 0;
  padding: 10px 11px;
  border: 1px solid #f4d8d8;
  border-radius: 7px;
  background: #fff8f8;
  color: #b64f55;
  font-size: 11px;
  line-height: 1.5;
}

.error-message svg {
  width: 16px;
  height: 16px;
  flex: 0 0 auto;
}

.welcome-card {
  display: flex;
  min-height: 265px;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  margin-top: 20px;
  padding: 20px;
  border: 1px dashed #e5e4ef;
  border-radius: 14px;
  background: linear-gradient(135deg, #fff 5%, #fbfaff 100%);
  text-align: center;
}

.welcome-illustration {
  position: relative;
  display: grid;
  width: 190px;
  height: 111px;
  place-items: center;
  margin-bottom: 11px;
}

.illustration-glow {
  position: absolute;
  inset: 17px 15px 5px;
  border-radius: 50%;
  background: #eae7ff;
  filter: blur(22px);
}

.illustration-chart {
  position: relative;
  width: 178px;
  height: 94px;
  overflow: hidden;
  border: 1px solid #efedf9;
  border-radius: 10px;
  background: #ffffffed;
  box-shadow: 0 7px 20px #6156bb0d;
}

.chart-grid-line {
  position: absolute;
  right: 10px;
  left: 10px;
  border-top: 1px dashed #edecf4;
}

.line-one { top: 25px; }
.line-two { top: 48px; }
.line-three { top: 71px; }

.bar {
  position: absolute;
  bottom: 11px;
  width: 13px;
  border-radius: 4px 4px 1px 1px;
  background: linear-gradient(180deg, #c5bcff, #e8e5ff);
}

.bar-one { left: 22px; height: 26px; }
.bar-two { left: 49px; height: 39px; }
.bar-three { left: 76px; height: 31px; }
.bar-four { left: 103px; height: 53px; }
.bar-five { left: 130px; height: 65px; }

.chart-trend {
  position: absolute;
  inset: 9px 7px auto auto;
  width: 151px;
  height: 59px;
}

.floating-sparkle {
  position: absolute;
  color: #8e7ef0;
}

.sparkle-one {
  top: 8px;
  right: 5px;
  font-size: 15px;
}

.sparkle-two {
  bottom: 15px;
  left: 1px;
  color: #b09ff2;
  font-size: 12px;
}

.welcome-card h2 {
  margin: 0;
  color: #44455c;
  font-size: 13px;
  font-weight: 680;
}

.welcome-card p {
  margin: 8px 0 0;
  color: #9698a8;
  font-size: 10px;
}

.result-section {
  margin-top: 29px;
  animation: appear 260ms ease both;
}

.chart-result-card {
  margin-top: 14px;
}

.chart-card-heading {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin: 0 2px 8px;
}

.chart-card-heading h3 {
  margin: 0;
  color: #44455c;
  font-size: 13px;
  font-weight: 680;
}

@keyframes appear {
  from { opacity: 0; transform: translateY(6px); }
  to { opacity: 1; transform: translateY(0); }
}

.result-heading {
  justify-content: space-between;
  gap: 14px;
  margin: 0 1px 13px;
}

.result-eyebrow {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-bottom: 6px;
  color: #8a8b9b;
  font-size: 9px;
  font-weight: 650;
  letter-spacing: 0.4px;
}

.result-eyebrow span {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #4abb83;
}

.result-heading h2 {
  margin: 0;
  color: #303148;
  font-size: 17px;
  font-weight: 700;
  letter-spacing: -0.3px;
}

.result-meta {
  gap: 9px;
}

.chart-type-badge {
  padding: 5px 8px;
  border: 1px solid #e7e4fa;
  border-radius: 5px;
  background: #f7f5ff;
  color: #7667d9;
  font-size: 9px;
  font-weight: 600;
}

.row-count {
  color: #9294a3;
  font-size: 10px;
}

.chart-card {
  position: relative;
  min-height: 500px;
  padding: 10px;
  border: 1px solid #e9e8f1;
  border-radius: 12px;
  background: #fff;
  box-shadow: 0 4px 15px #31315405;
}

.chart-canvas {
  width: 100%;
  height: 500px;
}

.empty-chart {
  position: absolute;
  inset: 0;
  display: grid;
  place-items: center;
  color: #999aaa;
  font-size: 12px;
  pointer-events: none;
}

.data-details {
  margin-top: 10px;
  border: 1px solid #e9e8f1;
  border-radius: 9px;
  background: white;
}

.data-details summary {
  display: flex;
  min-height: 43px;
  align-items: center;
  justify-content: space-between;
  padding: 0 13px;
  color: #57596e;
  cursor: pointer;
  font-size: 10px;
  font-weight: 600;
  list-style: none;
}

.data-details summary::-webkit-details-marker {
  display: none;
}

.details-leading {
  gap: 8px;
}

.details-leading svg {
  width: 17px;
  height: 17px;
  color: #85869a;
}

.details-count {
  color: #a0a1af;
  font-size: 9px;
  font-weight: 450;
}

.table-wrap {
  max-height: 290px;
  overflow: auto;
  border-top: 1px solid #f0eff5;
}

.table-wrap table {
  width: 100%;
  border-collapse: collapse;
  color: #66687b;
  font-size: 10px;
  text-align: left;
}

.table-wrap th,
.table-wrap td {
  padding: 9px 13px;
  border-bottom: 1px solid #f1f0f5;
  white-space: nowrap;
}

.table-wrap th {
  position: sticky;
  top: 0;
  background: #fafafd;
  color: #818394;
  font-size: 9px;
  font-weight: 650;
}

.table-wrap tr:last-child td {
  border-bottom: 0;
}

.no-rows {
  margin: 0;
  padding: 15px;
  color: #9698a8;
  font-size: 10px;
}

.sql-details pre {
  max-height: 220px;
  overflow: auto;
  margin: 0;
  padding: 14px;
  border-top: 1px solid #f0eff5;
  background: #fafafd;
  color: #55576d;
  font-size: 10px;
  line-height: 1.7;
  white-space: pre-wrap;
  word-break: break-word;
}

.page-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-top: 20px;
  color: #a1a2b0;
  font-size: 9px;
}

.page-footer span:first-child {
  display: inline-flex;
  align-items: center;
  gap: 7px;
}

.page-footer i {
  width: 5px;
  height: 5px;
}

.page-footer b {
  padding: 0 3px;
  color: #c1c1cc;
  font-weight: 400;
}

.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  clip-path: inset(50%);
}

@media (max-width: 1050px) {
  .page-body {
    padding-right: 34px;
    padding-left: 34px;
  }

  .topbar {
    padding-right: 34px;
    padding-left: 34px;
  }

  .examples {
    align-items: flex-start;
  }
}

@media (max-width: 760px) {
  .sidebar {
    position: static;
    width: 100%;
    height: 58px;
    flex-direction: row;
    align-items: center;
    justify-content: space-between;
    padding: 0 19px;
    border-right: 0;
    border-bottom: 1px solid #ececf3;
  }

  .brand {
    gap: 8px;
    margin: 0;
  }

  .brand-mark {
    width: 31px;
    height: 31px;
    border-radius: 9px;
  }

  .brand-mark svg {
    width: 22px;
    height: 22px;
  }

  .brand-name {
    font-size: 15px;
  }

  .sidebar-label,
  .side-nav,
  .sidebar-bottom {
    display: none;
  }

  .main-content {
    min-height: calc(100vh - 58px);
    margin-left: 0;
  }

  .topbar {
    height: 52px;
    padding: 0 20px;
  }

  .page-body {
    padding: 48px 22px 23px;
  }

  .intro {
    margin-bottom: 24px;
  }

  .intro h1 {
    font-size: clamp(31px, 7vw, 39px);
  }

  .intro-copy {
    max-width: 360px;
    margin-right: auto;
    margin-left: auto;
    font-size: 12px;
    line-height: 1.7;
  }

  .prompt-panel {
    padding: 17px 15px 14px;
  }

  .welcome-card {
    min-height: 240px;
  }
}

@media (max-width: 480px) {
  body {
    min-width: 320px;
  }

  .topbar {
    padding: 0 15px;
  }

  .secure-label {
    display: none;
  }

  .page-body {
    padding: 39px 14px 20px;
  }

  .intro h1 {
    letter-spacing: -1.4px;
  }

  .prompt-panel-top {
    align-items: flex-start;
  }

  .model-badge {
    padding: 5px 7px;
    font-size: 9px;
  }

  .prompt-heading-wrap h2 {
    font-size: 12px;
  }

  .examples-label {
    width: 100%;
  }

  .input-hint {
    gap: 3px;
    font-size: 8px;
  }

  .char-count {
    display: none;
  }

  .generate-button {
    gap: 5px;
    padding: 0 9px;
    font-size: 9px;
  }

  .result-heading {
    align-items: flex-start;
  }

  .result-heading h2 {
    font-size: 15px;
  }

  .result-meta {
    flex-direction: column;
    align-items: flex-end;
    gap: 5px;
  }

  .chart-card {
    min-height: 340px;
    padding: 5px;
  }

  .chart-canvas {
    height: 340px;
  }

  .page-footer {
    align-items: flex-start;
    font-size: 8px;
  }
}
</style>
