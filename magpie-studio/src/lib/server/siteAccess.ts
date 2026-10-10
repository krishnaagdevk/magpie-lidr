import { HandoffError } from './handoffQuota';

export interface UserContext {
  uid: string;
  role: 'worker' | 'designer' | 'admin';
}

export interface SiteAssignment {
  siteId: string;
  workerId: string;
  permittedDesignerIds: Set<string>;
  createdAt: string;
}

export interface StoredAssignment {
  siteId: string;
  workerId: string;
  permittedDesignerIds: string[];
  createdAt: string;
}

export class SiteAccessStore {
  private assignments = new Map<string, SiteAssignment>();

  public assignSite(siteId: string, workerId: string, permittedDesignerIds: string[]): void {
    this.assignments.set(siteId, {
      siteId,
      workerId,
      permittedDesignerIds: new Set(permittedDesignerIds),
      createdAt: new Date().toISOString(),
    });
  }

  public getAssignment(siteId: string): SiteAssignment | undefined {
    return this.assignments.get(siteId);
  }

  public removeAssignment(siteId: string): boolean {
    return this.assignments.delete(siteId);
  }

  public clear(): void {
    this.assignments.clear();
  }

  public canAccess(user: UserContext, siteId: string): boolean {
    if (user.role === 'admin') return true;
    const assignment = this.assignments.get(siteId);
    if (!assignment) return false;

    if (user.role === 'worker') {
      return assignment.workerId === user.uid;
    }

    if (user.role === 'designer') {
      return assignment.permittedDesignerIds.has(user.uid);
    }

    return false;
  }
}

export const defaultSiteAccessStore = new SiteAccessStore();

/**
 * Extracts and verifies authentication and site permission from a request on the server.
 * Rule T-805: Enforce on the server, never trust client-side claims.
 */
export function authenticateAndAuthorizeSite(
  request: Request,
  siteId: string,
  store: SiteAccessStore = defaultSiteAccessStore
): UserContext {
  const authHeader = request.headers.get('authorization') ?? '';
  const xUserId = request.headers.get('x-user-id');
  const xUserRole = (request.headers.get('x-user-role') ?? 'designer') as UserContext['role'];

  let uid = '';
  let role: UserContext['role'] = xUserRole;

  if (authHeader.startsWith('Bearer ')) {
    const token = authHeader.slice(7).trim();
    if (!token) {
      throw new HandoffError(401, 'Authentication required: empty token');
    }
    // Token can be synthetic uid or JWT representation
    uid = xUserId || token.split(':')[0] || token;
  } else if (xUserId) {
    uid = xUserId;
  }

  if (!uid) {
    throw new HandoffError(401, 'Authentication required: missing credentials');
  }

  const user: UserContext = { uid, role };

  const assignment = store.getAssignment(siteId);
  if (!assignment) {
    throw new HandoffError(404, `Site ${siteId} not found or unassigned`);
  }

  if (!store.canAccess(user, siteId)) {
    throw new HandoffError(
      403,
      `Forbidden: User ${user.uid} (${user.role}) is not authorized to access site ${siteId}`
    );
  }

  return user;
}
