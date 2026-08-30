import { createRouter, createWebHistory } from 'vue-router'
import { getToken } from '@/lib/auth'
import AppsView from '@/views/AppsView.vue'
import AppDetailView from '@/views/AppDetailView.vue'
import HomeView from '@/views/HomeView.vue'
import LoginView from '@/views/LoginView.vue'
import SettingsView from '@/views/SettingsView.vue'
import StackDetailView from '@/views/StackDetailView.vue'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    { path: '/login', name: 'login', component: LoginView, meta: { public: true } },
    { path: '/', name: 'home', component: HomeView, meta: { requiresAuth: true } },
    { path: '/apps', name: 'apps', component: AppsView, meta: { requiresAuth: true } },
    { path: '/stacks/:stem', name: 'stack', component: StackDetailView, meta: { requiresAuth: true } },
    { path: '/apps/:appId', name: 'app-detail', component: AppDetailView, meta: { requiresAuth: true } },
    { path: '/settings', name: 'settings', component: SettingsView, meta: { requiresAuth: true } },
  ],
})

router.beforeEach((to) => {
  const token = getToken()
  if (to.meta.public) {
    if (to.path === '/login' && token) return '/apps'
    return true
  }
  if (to.meta.requiresAuth && !token) {
    return { name: 'login', query: { redirect: to.fullPath } }
  }
  return true
})

export default router
