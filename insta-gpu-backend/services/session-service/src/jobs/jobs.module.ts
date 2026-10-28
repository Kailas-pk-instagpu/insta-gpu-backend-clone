import { Module } from "@nestjs/common";

// Scheduled jobs come later (each takes a PostgreSQL advisory lock).
@Module({})
export class JobsModule {}
