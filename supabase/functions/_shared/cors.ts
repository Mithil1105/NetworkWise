// -----------------------------------------------------------------------------
// Shared CORS helper for every Supabase Edge Function.
// -----------------------------------------------------------------------------
// The Flutter desktop client sends requests from `http://localhost` (or
// `file://` depending on the build), so we keep CORS fully permissive
// here. Tighten if you ever expose these endpoints to a public web app.
// -----------------------------------------------------------------------------

export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-org-id, x-device-id",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

export function jsonResponse(
  body: unknown,
  init: ResponseInit = {},
): Response {
  return new Response(JSON.stringify(body), {
    ...init,
    headers: {
      ...corsHeaders,
      "content-type": "application/json; charset=utf-8",
      ...(init.headers ?? {}),
    },
  });
}
