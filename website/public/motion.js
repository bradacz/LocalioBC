// Presentation effects and playback of the user-supplied CDN video. No analytics or storage.
(() => {
  const preference = window.matchMedia('(prefers-reduced-motion: reduce)');
  const video = document.querySelector('.hero-film video');
  const toggle = document.querySelector('.video-toggle');
  if (video && toggle) {
    video.muted = true;
    video.controls = false;
    toggle.hidden = false;
    const update = () => {
      toggle.textContent = video.paused ? toggle.dataset.play : toggle.dataset.pause;
    };
    toggle.addEventListener('click', () => {
      if (video.paused) video.play().catch(update);
      else video.pause();
    });
    video.addEventListener('play', update);
    video.addEventListener('pause', update);
    preference.addEventListener('change', event => {
      if (event.matches) video.pause();
    });
    if (!preference.matches) video.play().catch(update);
    update();
  }
  if (preference.matches || !('IntersectionObserver' in window)) return;

  const header = document.querySelector('header');
  const preview = document.querySelector('.screen');
  const progress = document.createElement('div');
  progress.className = 'scroll-progress';
  progress.setAttribute('aria-hidden', 'true');
  document.body.prepend(progress);

  const observer = new IntersectionObserver(entries => {
    for (const entry of entries) {
      if (!entry.isIntersecting) continue;
      entry.target.classList.add('is-visible');
      observer.unobserve(entry.target);
    }
  }, { threshold: 0.08, rootMargin: '0px 0px -24px 0px' });

  const targets = [...document.querySelectorAll('.hero > *, .screen, .feature, .notice, .prose > h1, .prose > h2, .prose > p, .prose > details')];
  targets.forEach((element, index) => {
    const siblings = element.classList.contains('feature')
      ? [...element.parentElement.children].indexOf(element) : index % 3;
    element.style.setProperty('--reveal-delay', `${siblings * 65}ms`);
    element.classList.add('reveal');
    observer.observe(element);
  });

  let pending = false;
  let stopped = false;
  function paint() {
    pending = false;
    if (stopped) return;
    const y = window.scrollY;
    const range = document.documentElement.scrollHeight - window.innerHeight;
    const fraction = range > 0 ? Math.max(0, Math.min(1, y / range)) : 0;
    progress.style.transform = `scaleX(${fraction.toFixed(4)})`;
    header?.classList.toggle('is-scrolled', y > 18);
    if (preview) {
      const bounds = preview.getBoundingClientRect();
      const distance = (window.innerHeight / 2 - bounds.top - bounds.height / 2) / window.innerHeight;
      const shift = Math.max(-14, Math.min(14, distance * 18));
      preview.style.setProperty('--preview-shift', `${shift.toFixed(2)}px`);
    }
  }
  function schedule() {
    if (!pending && !stopped) {
      pending = true;
      window.requestAnimationFrame(paint);
    }
  }
  window.addEventListener('scroll', schedule, { passive: true });
  window.addEventListener('resize', schedule, { passive: true });
  window.addEventListener('load', schedule, { once: true });
  preference.addEventListener('change', event => {
    if (!event.matches) return;
    stopped = true;
    observer.disconnect();
    window.removeEventListener('scroll', schedule);
    window.removeEventListener('resize', schedule);
    targets.forEach(element => element.classList.add('is-visible'));
    preview?.style.removeProperty('--preview-shift');
    progress.remove();
  });
  schedule();
})();
