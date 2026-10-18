// expiresAt is a unix time in seconds, as issued by the identity provider.
export function isExpired(token) {
  return Date.now() > token.expiresAt;
}
