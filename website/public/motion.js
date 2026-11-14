// Local presentation effects only. No analytics, storage, or network requests.
(() => {
  const preference = window.matchMedia('(prefers-reduced-motion: reduce)');
  const hero = document.querySelector('.hero');
  const finePointer = window.matchMedia('(hover: hover) and (pointer: fine)');
  if (hero) {
    let frame = 0;
    let bounds;
    let point;
    let attached = false;
    const invalidateBounds = () => { bounds = undefined; };
    const clear = () => {
      window.cancelAnimationFrame(frame);
      frame = 0;
      bounds = undefined;
      point = undefined;
      hero.style.removeProperty('--art-x');
      hero.style.removeProperty('--art-y');
      hero.style.removeProperty('--art-tilt');
    };
    const paintArtwork = () => {
      frame = 0;
      if (!point || preference.matches || !finePointer.matches) return;
      bounds ??= hero.getBoundingClientRect();
      const x = Math.max(-1, Math.min(1, (point.x - bounds.left) / bounds.width * 2 - 1));
      const y = Math.max(-1, Math.min(1, (point.y - bounds.top) / bounds.height * 2 - 1));
      hero.style.setProperty('--art-x', `${(x * 12).toFixed(2)}px`);
      hero.style.setProperty('--art-y', `${(y * 9).toFixed(2)}px`);
      hero.style.setProperty('--art-tilt', `${(x * 1.5).toFixed(2)}deg`);
    };
    const move = event => {
      if (event.pointerType === 'touch') return;
      point = { x: event.clientX, y: event.clientY };
      if (!frame) frame = window.requestAnimationFrame(paintArtwork);
    };
    const configureArtwork = () => {
      const enabled = !preference.matches && finePointer.matches;
      if (enabled === attached) return;
      attached = enabled;
      if (enabled) {
        hero.addEventListener('pointermove', move, { passive: true });
        hero.addEventListener('pointerleave', clear, { passive: true });
        window.addEventListener('scroll', invalidateBounds, { passive: true });
        window.addEventListener('resize', invalidateBounds, { passive: true });
      } else {
        hero.removeEventListener('pointermove', move);
        hero.removeEventListener('pointerleave', clear);
        window.removeEventListener('scroll', invalidateBounds);
        window.removeEventListener('resize', invalidateBounds);
        clear();
      }
    };
    preference.addEventListener('change', configureArtwork);
    finePointer.addEventListener('change', configureArtwork);
    configureArtwork();
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

  const targets = [...document.querySelectorAll('.hero-content > *, .screen, .feature, .release-news, .notice, .prose > h1, .prose > h2, .prose > p, .prose > details')];
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
