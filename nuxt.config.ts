// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: '2025-07-15',
  devtools: { enabled: true },
  runtimeConfig: {
    database: {
      dialect: 'mysql',
      host: 'localhost',
      port: 3306,
      user: '',
      password: '',
      name: '',
    },
    public: {
      apiBase: '', // can be overridden by NUXT_PUBLIC_API_BASE environment variable
    },
  }
})
