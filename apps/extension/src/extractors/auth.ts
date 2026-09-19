import { clean } from './dom';

export function isAuthenticationPage(document: Document, responseUrl?: string): boolean {
  let loginPath = false;
  if (responseUrl) {
    const url = new URL(responseUrl, 'https://flm.fpt.edu.vn');
    loginPath = /\/(login|signin)(\/|$)/i.test(url.pathname) || /\/(account|auth)\/(login|signin)(\/|$)/i.test(url.pathname);
  }
  const password = document.querySelector('input[type="password"]');
  const form = password?.closest('form');
  if (loginPath && password) return true;
  if (!form || !password) return false;
  const hasIdentity = Boolean(form.querySelector('input[type="email"], input[name*="user" i], input[name*="email" i]'));
  const hasSubmit = Boolean(form.querySelector('button[type="submit"], input[type="submit"]'));
  return hasIdentity && hasSubmit && clean(form.textContent).length > 0;
}
