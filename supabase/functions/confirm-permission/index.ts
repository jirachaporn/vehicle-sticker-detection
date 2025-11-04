import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

Deno.serve(async (req: Request) => {
  try {
    const url = new URL(req.url);
    const logId = url.searchParams.get("permissionLogId")?.trim();

    if (!logId) {
      return new Response("❌ Invalid link (missing permissionLogId)", {
        status: 400,
        headers: { "Content-Type": "text/plain; charset=utf-8" },
      });
    }

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE, {
      auth: { persistSession: false },
    });

    // ดึงข้อมูล invitation จาก permission_log
    const { data: logData, error: logError } = await admin
      .from("permission_log")
      .select("*")
      .eq("permission_log_id", logId)
      .single();

    if (logError || !logData) {
      return new Response("❌ Invitation not found", {
        status: 404,
        headers: { "Content-Type": "text/plain; charset=utf-8" },
      });
    }

    const { member_email, location_id, permission, member_name } = logData;

    // เช็คว่าผู้ใช้มีอยู่ใน location_members หรือยัง
    const { data: existsData } = await admin
      .from("location_members")
      .select("*")
      .eq("member_email", member_email)
      .eq("location_id", location_id)
      .maybeSingle();

    if (existsData) {
      return new Response("ℹAlready confirmed", {
        status: 200,
        headers: { "Content-Type": "text/plain; charset=utf-8" },
      });
    }

    // ถ้าไม่มี ให้เพิ่มลง location_members
    await admin.from("location_members").insert({
      location_id,
      member_email,
      member_name: member_name || "Unknown",
      member_permission: permission,
    });

    return new Response("✅ Permission confirmed successfully", {
      status: 200,
      headers: { "Content-Type": "text/plain; charset=utf-8" },
    });
  } catch (e) {
    return new Response("❌ Unexpected error: " + String(e), {
      status: 500,
      headers: { "Content-Type": "text/plain; charset=utf-8" },
    });
  }
});
