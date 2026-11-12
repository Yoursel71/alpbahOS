import { defineConfig } from 'vitepress'

const sidebar = [
  { text: 'Genel bakış', items: [{ text: 'Giriş', link: '/' }, { text: 'Başlarken', link: '/baslarken' }, { text: 'Kurulum', link: '/kurulum' }] },
  { text: 'Masaüstü', items: [{ text: 'Hoş Geldin ve temalar', link: '/hos-geldin' }, { text: 'Masaüstü kullanımı', link: '/masaustu' }, { text: 'alp paket yöneticisi', link: '/alp' }, { text: 'Yazıcı ve ağ', link: '/yazici-ag' }] },
  { text: 'Proje', items: [{ text: 'Sistem gereksinimleri', link: '/gereksinimler' }, { text: 'Sürüm durumu ve yol haritası', link: '/yol-haritasi' }, { text: 'Sık sorulan sorular', link: '/sss' }] }
]
export default defineConfig({
  lang: 'tr-TR', title: 'alpbahOS', description: 'alpbahOS Türkçe dokümantasyonu',
  cleanUrls: true, base: '/alpbahOS/',
  themeConfig: {
    logo: '/images/logo/alpbahOS-mark.svg', siteTitle: 'alpbahOS / docs', skipToContentLabel: 'İçeriğe geç',
    nav: [{ text: 'Belgeler', link: '/' }, { text: 'GitHub', link: 'https://github.com/Yoursel71/alpbahOS' }],
    sidebar,
    outline: { level: [2, 3], label: 'Bu sayfada' },
    docFooter: { prev: 'Önceki sayfa', next: 'Sonraki sayfa' },
    darkModeSwitchLabel: 'Görünüm', lightModeSwitchTitle: 'Açık tema', darkModeSwitchTitle: 'Koyu tema',
    sidebarMenuLabel: 'Menü', returnToTopLabel: 'Yukarı dön',
    search: { provider: 'local', options: { translations: { button: { buttonText: 'Belgelerde ara', buttonAriaLabel: 'Belgelerde ara' }, modal: { noResultsText: 'Sonuç bulunamadı', resetButtonTitle: 'Aramayı temizle', footer: { selectText: 'seç', navigateText: 'gezin', closeText: 'kapat' } } } } }
  },
  markdown: { codeCopyButtonTitle: 'Kodu kopyala', image: { lazyLoading: true } }
})
