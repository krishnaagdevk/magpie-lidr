import { describe, it, expect, beforeEach } from 'vitest';
import {
  SiteAccessStore,
  authenticateAndAuthorizeSite,
} from '$lib/server/siteAccess';

describe('T-805 — Per-site Access Control', () => {
  let store: SiteAccessStore;

  beforeEach(() => {
    store = new SiteAccessStore();
    // Site A: worker-1, designer-A
    store.assignSite('site-kitchen-A', 'worker-1', ['designer-A']);
    // Site B: worker-2, designer-B
    store.assignSite('site-kitchen-B', 'worker-2', ['designer-B']);
  });

  it('allows designer assigned to site A to access site A', () => {
    const req = new Request('https://example.test/api/handoffs/site-kitchen-A', {
      headers: {
        Authorization: 'Bearer designer-A:valid-token',
        'X-User-Id': 'designer-A',
        'X-User-Role': 'designer',
      },
    });

    const user = authenticateAndAuthorizeSite(req, 'site-kitchen-A', store);
    expect(user.uid).toBe('designer-A');
    expect(user.role).toBe('designer');
  });

  it('strictly forbids designer assigned to site A from accessing site B (even with hand-crafted request)', () => {
    const req = new Request('https://example.test/api/handoffs/site-kitchen-B', {
      headers: {
        Authorization: 'Bearer designer-A:forged-token',
        'X-User-Id': 'designer-A',
        'X-User-Role': 'designer',
      },
    });

    expect(() => authenticateAndAuthorizeSite(req, 'site-kitchen-B', store)).toThrowError(
      /Forbidden: User designer-A \(designer\) is not authorized to access site site-kitchen-B/
    );
  });

  it('allows worker who captured site A to access site A, but not site B', () => {
    const reqA = new Request('https://example.test/api/handoffs/site-kitchen-A', {
      headers: {
        Authorization: 'Bearer worker-1:token',
        'X-User-Id': 'worker-1',
        'X-User-Role': 'worker',
      },
    });

    expect(authenticateAndAuthorizeSite(reqA, 'site-kitchen-A', store).uid).toBe('worker-1');

    const reqB = new Request('https://example.test/api/handoffs/site-kitchen-B', {
      headers: {
        Authorization: 'Bearer worker-1:token',
        'X-User-Id': 'worker-1',
        'X-User-Role': 'worker',
      },
    });

    expect(() => authenticateAndAuthorizeSite(reqB, 'site-kitchen-B', store)).toThrowError(
      /Forbidden/
    );
  });

  it('rejects unauthenticated requests with HTTP 401', () => {
    const req = new Request('https://example.test/api/handoffs/site-kitchen-A');
    expect(() => authenticateAndAuthorizeSite(req, 'site-kitchen-A', store)).toThrowError(
      /Authentication required/
    );
  });

  it('rejects requests to non-existent unassigned sites with HTTP 404', () => {
    const req = new Request('https://example.test/api/handoffs/site-kitchen-nonexistent', {
      headers: {
        Authorization: 'Bearer designer-A:token',
        'X-User-Id': 'designer-A',
      },
    });

    expect(() => authenticateAndAuthorizeSite(req, 'site-kitchen-nonexistent', store)).toThrowError(
      /Site site-kitchen-nonexistent not found/
    );
  });
});
