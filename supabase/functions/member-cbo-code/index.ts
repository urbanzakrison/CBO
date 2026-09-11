import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ ok: false, error: "Method not allowed" }, 405);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceRoleKey) throw new Error("Supabase server secrets saknas.");

    const authHeader = req.headers.get("Authorization") || "";
    const jwt = authHeader.replace(/^Bearer\s+/i, "").trim();
    if (!jwt) return json({ ok: false, error: "Du måste vara inloggad." }, 401);

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: userData, error: userError } = await admin.auth.getUser(jwt);
    if (userError || !userData?.user) {
      return json({ ok: false, error: "Ogiltig eller utgången CBO-session." }, 401);
    }

    const body = await req.json().catch(() => ({}));
    const newCode = String(body?.new_code || "");
    if (newCode.length < 8) return json({ ok: false, error: "CBO-koden måste vara minst 8 tecken." }, 400);
    if (newCode.length > 64) return json({ ok: false, error: "CBO-koden får vara högst 64 tecken." }, 400);

    const { data: cred, error: credError } = await admin
      .from("player_credentials")
      .select("player_id,auth_user_id")
      .eq("auth_user_id", userData.user.id)
      .maybeSingle();
    if (credError) throw credError;
    if (!cred?.player_id || cred.auth_user_id !== userData.user.id) {
      return json({ ok: false, error: "Kontot är inte kopplat till en CBO-medlem." }, 403);
    }

    const { data: player, error: playerError } = await admin
      .from("players")
      .select("id,name,active")
      .eq("id", cred.player_id)
      .maybeSingle();
    if (playerError) throw playerError;
    if (!player || player.active === false) {
      return json({ ok: false, error: "CBO-medlemmen är inte aktiv." }, 403);
    }

    const { error: authUpdateError } = await admin.auth.admin.updateUserById(userData.user.id, {
      password: newCode,
    });
    if (authUpdateError) throw authUpdateError;

    const { error: codeSyncError } = await admin.rpc("cbo_set_player_code", {
      p_player_id: cred.player_id,
      p_code: newCode,
    });
    if (codeSyncError) throw codeSyncError;

    const now = new Date().toISOString();
    const { error: stampError } = await admin
      .from("player_credentials")
      .update({ code_initialized_at: now, updated_at: now })
      .eq("player_id", cred.player_id);
    if (stampError) throw stampError;

    return json({ ok: true, message: "Din CBO-kod är ändrad." });
  } catch (e) {
    console.error(e);
    return json({ ok: false, error: e instanceof Error ? e.message : String(e) }, 400);
  }
});
