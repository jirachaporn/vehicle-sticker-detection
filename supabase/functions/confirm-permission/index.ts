import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

Deno.serve(async (req: Request) => {
  try {
    const url = new URL(req.url);
    const token = url.searchParams.get("token")?.trim();

    if (!token) {
      return new Response("❌ Invalid link (missing token)", {
        status: 400,
        headers: { "Content-Type": "text/plain; charset=utf-8" },
      });
    }

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE, {
      auth: { persistSession: false },
    });

    const { data, error } = await admin.rpc("core_accept_invite", { p_token: token });

    if (error) {
      return new Response("❌ Error occurred: " + error.message, {
        status: 500,
        headers: { "Content-Type": "text/plain; charset=utf-8" },
      });
    }

    if (data?.ok === true) {
      return new Response("✅ Permission confirmed successfully — please return to the app.", {
        status: 200,
        headers: { "Content-Type": "text/plain; charset=utf-8" },
      });
    } else {
      return new Response("❌ Confirmation failed. Reason: " + (data?.reason ?? "unknown"), {
        status: 400,
        headers: { "Content-Type": "text/plain; charset=utf-8" },
      });
    }
  } catch (e) {
    return new Response("❌ Unexpected error: " + String(e), {
      status: 500,
      headers: { "Content-Type": "text/plain; charset=utf-8" },
    });
  }
});
