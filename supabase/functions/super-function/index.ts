const ALLOWED_ORIGINS = new Set([
  "http://localhost:8000",
  "http://127.0.0.1:8000",
  "https://maryco-it-support.netlify.app",
]);

function getCorsHeaders(req: Request) {
  const origin = req.headers.get("origin") ?? "";

  const headers: Record<string, string> = {
    "Access-Control-Allow-Headers":
      "authorization, apikey, content-type, x-client-info",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };

  if (ALLOWED_ORIGINS.has(origin)) {
    headers["Access-Control-Allow-Origin"] = origin;
  }

  return headers;
}

function jsonResponse(
  req: Request,
  body: unknown,
  status = 200,
) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...getCorsHeaders(req),
      "Content-Type": "application/json",
    },
  });
}

Deno.serve(async (req) => {
  const origin = req.headers.get("origin") ?? "";

  if (origin && !ALLOWED_ORIGINS.has(origin)) {
    return jsonResponse(req, { error: "Origin not allowed" }, 403);
  }

  if (req.method === "OPTIONS") {
    return new Response("ok", {
      status: 200,
      headers: getCorsHeaders(req),
    });
  }

  if (req.method !== "POST") {
    return jsonResponse(req, { error: "Method not allowed" }, 405);
  }

  try {
    const suppliedKey = req.headers.get("apikey") ?? "";

    const publishableKeys = JSON.parse(
      Deno.env.get("SUPABASE_PUBLISHABLE_KEYS") ?? "{}",
    );

    const validKeys = Object.values(publishableKeys);
    const legacyAnonKey = Deno.env.get("SUPABASE_ANON_KEY");

    if (
      !validKeys.includes(suppliedKey) &&
      suppliedKey !== legacyAnonKey
    ) {
      return jsonResponse(req, { error: "Unauthorized" }, 401);
    }

    const claudeKey = Deno.env.get("CLAUDE_API_KEY");

    if (!claudeKey) {
      return jsonResponse(
        req,
        { error: "CLAUDE_API_KEY is not configured" },
        500,
      );
    }

    const body = await req.json();
    const system =
      typeof body.system === "string" ? body.system : "";

    const messages = Array.isArray(body.messages)
      ? body.messages
      : [];

    if (!system || messages.length === 0) {
      return jsonResponse(
        req,
        { error: "System prompt and messages are required" },
        400,
      );
    }

    if (
      system.length > 20000 ||
      messages.length > 30 ||
      JSON.stringify(messages).length > 30000
    ) {
      return jsonResponse(
        req,
        { error: "Request is too large" },
        413,
      );
    }

    const claudeResponse = await fetch(
      "https://api.anthropic.com/v1/messages",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": claudeKey,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({
          model: "claude-sonnet-4-5",
          max_tokens: 1024,
          system,
          messages,
        }),
      },
    );

    const result = await claudeResponse.text();

    return new Response(result, {
      status: claudeResponse.status,
      headers: {
        ...getCorsHeaders(req),
        "Content-Type": "application/json",
      },
    });
  } catch (error) {
    console.error("super-function error:", error);

    return jsonResponse(
      req,
      { error: "The chatbot service encountered an error" },
      500,
    );
  }
});
