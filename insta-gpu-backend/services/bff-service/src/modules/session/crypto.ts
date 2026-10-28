import { createCipheriv, createDecipheriv, createHash, randomBytes } from "node:crypto";
import { cfg } from "../../config";

/**
 * Ported from the reference console lib/crypto.ts. AES-256-GCM with SESSION_ENCRYPTION_KEY for (a) the short-lived login cookie
 * (state + PKCE verifier) and (b) tokens at rest in identity.bff_sessions. Ciphertexts carry a "local:" prefix so an OpenBao Transit
 * encryptor can take over later without breaking stored sessions.
 */
const key = () => Buffer.from(cfg().SESSION_ENCRYPTION_KEY, "base64");

export function seal(obj: unknown): string {
  const iv = randomBytes(12);
  const c = createCipheriv("aes-256-gcm", key(), iv);
  const data = Buffer.concat([c.update(JSON.stringify(obj), "utf8"), c.final()]);
  return Buffer.concat([iv, c.getAuthTag(), data]).toString("base64url");
}

export function unseal<T>(token: string): T | null {
  try {
    const buf = Buffer.from(token, "base64url");
    const d = createDecipheriv("aes-256-gcm", key(), buf.subarray(0, 12));
    d.setAuthTag(buf.subarray(12, 28));
    return JSON.parse(Buffer.concat([d.update(buf.subarray(28)), d.final()]).toString("utf8")) as T;
  } catch {
    return null;
  }
}

export const encrypt = (plain: string) => `local:${seal(plain)}`;
export function decrypt(cipher: string): string {
  const v = unseal<string>(cipher.replace(/^local:/, ""));
  if (v == null) throw new Error("bad ciphertext");
  return v;
}

export const sha256 = (s: string) => createHash("sha256").update(s).digest("hex");
export const randomToken = (bytes = 32) => randomBytes(bytes).toString("base64url");
