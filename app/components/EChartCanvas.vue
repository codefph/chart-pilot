<script setup lang="ts">
import type { ECharts } from 'echarts/core';
import type { EChartsOption } from 'echarts';

const props = defineProps<{
  option: EChartsOption;
  ariaLabel: string;
}>();

const container = ref<HTMLDivElement | null>(null);
let chart: ECharts | undefined;
let resizeObserver: ResizeObserver | undefined;

async function renderChart() {
  if (!container.value) {
    return;
  }

  if (!chart) {
    const echarts = await import('echarts');
    chart = echarts.init(container.value);
  }

  chart.setOption(props.option, true);
  chart.resize();
}

watch(() => props.option, () => {
  void renderChart();
}, { deep: true });

onMounted(() => {
  void renderChart();
  resizeObserver = new ResizeObserver(() => chart?.resize());
  if (container.value) {
    resizeObserver.observe(container.value);
  }
});

onBeforeUnmount(() => {
  resizeObserver?.disconnect();
  chart?.dispose();
  chart = undefined;
});
</script>

<template>
  <div ref="container" class="chart-canvas" role="img" :aria-label="ariaLabel" />
</template>
