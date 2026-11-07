// yunaui.com: serves the static site and keeps the shared heart counter.
export class Likes {
  constructor(state) {
    this.sql = state.storage.sql;
    this.sql.exec("CREATE TABLE IF NOT EXISTS fans (id TEXT PRIMARY KEY, at INTEGER)");
  }
  count() { return this.sql.exec("SELECT COUNT(*) AS n FROM fans").one().n; }
  has(id) { return this.sql.exec("SELECT 1 FROM fans WHERE id = ?", id).toArray().length > 0; }
  async fetch(req) {
    const id = new URL(req.url).searchParams.get("id") || "";
    if (req.method === "POST" && id && !this.has(id)) {
      this.sql.exec("INSERT INTO fans (id, at) VALUES (?, ?)", id, Date.now());
    }
    return Response.json({ count: this.count(), liked: id ? this.has(id) : false });
  }
}

async function visitorId(req) {
  const ip = req.headers.get("CF-Connecting-IP") || "unknown";
  const data = new TextEncoder().encode("yunaui-heart:" + ip);
  const hash = await crypto.subtle.digest("SHA-256", data);
  return [...new Uint8Array(hash)].map(b => b.toString(16).padStart(2, "0")).join("").slice(0, 32);
}

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    if (url.pathname === "/api/likes") {
      if (req.method !== "GET" && req.method !== "POST") return new Response("Method not allowed", { status: 405 });
      const stub = env.LIKES.get(env.LIKES.idFromName("global"));
      const res = await stub.fetch("https://likes/?id=" + (await visitorId(req)), { method: req.method });
      return new Response(res.body, { headers: { "content-type": "application/json", "cache-control": "no-store" } });
    }
    return env.ASSETS.fetch(req);
  }
};
