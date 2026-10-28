import { Injectable } from "@nestjs/common";
import type { PrincipalResolver, ResolvedPerson, TokenIdentity } from "@instagpu/shared-auth";
import { UsersRepository } from "./users.repository";

/**
 * auth-service is the only service that reads identity tables directly, so it resolves principals from the database
 * (the other services ask it over /internal/principals/:sub). Runs on every authenticated request.
 */
@Injectable()
export class UsersService implements PrincipalResolver {
  constructor(private readonly repo: UsersRepository) {}

  async resolve(identity: TokenIdentity): Promise<ResolvedPerson | null> {
    const user = await this.repo.upsertBySub(identity);
    if (!user) return null;
    if (user.status !== "ACTIVE") return { userId: user.id, status: user.status, memberships: [] };
    return { userId: user.id, status: user.status, memberships: await this.repo.activeMemberships(user.id) };
  }

  findById(id: string) {
    return this.repo.findById(id);
  }
}
