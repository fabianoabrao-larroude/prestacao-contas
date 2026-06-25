// supabase/functions/admin-create-user/index.ts
// Deploy: supabase functions deploy admin-create-user

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  try {
    // 1. Validar Authorization header
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "Authorization header ausente" }, 401);

    // 2. Cliente com JWT do chamador para validar identidade
    const supabaseUser = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: authErr } = await supabaseUser.auth.getUser();
    if (authErr || !user) return json({ error: "Sessão inválida" }, 401);

    // 3. Cliente admin com service_role (nunca exposto no frontend)
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // 4. Verificar se chamador é ADMIN ativo
    const { data: caller } = await admin
      .from("usuarios")
      .select("perfil, ativo")
      .eq("auth_user_id", user.id)
      .single();

    if (!caller || caller.perfil !== "ADMIN" || !caller.ativo) {
      return json({ error: "Acesso negado: apenas ADMINs podem criar usuários" }, 403);
    }

    // 5. Parse do body
    const body = await req.json();
    const { nome, email, perfil, centros_custo = [], cartoes = [] } = body;

    if (!nome?.trim() || !email?.trim() || !perfil) {
      return json({ error: "nome, email e perfil são obrigatórios" }, 400);
    }
    if (!["ADMIN", "GESTOR", "USUARIO"].includes(perfil)) {
      return json({ error: "perfil inválido. Use: ADMIN, GESTOR ou USUARIO" }, 400);
    }

    // 6. Verificar duplicidade de e-mail
    const { data: existing } = await admin
      .from("usuarios")
      .select("id")
      .eq("email", email.toLowerCase().trim())
      .maybeSingle();

    if (existing) return json({ error: "E-mail já cadastrado no sistema" }, 409);

    // 7. Enviar convite via Supabase Auth Admin API
    const { data: inviteData, error: inviteErr } = await admin.auth.admin.inviteUserByEmail(
      email.toLowerCase().trim(),
      { data: { nome, perfil } }
    );

    if (inviteErr) {
      return json({ error: `Erro ao enviar convite: ${inviteErr.message}` }, 500);
    }

    // 8. Gerar código sequencial
    const { count } = await admin
      .from("usuarios")
      .select("*", { count: "exact", head: true });
    const codigo = `USR${String((count ?? 0) + 1).padStart(3, "0")}`;

    // 9. Criar registro operacional
    const { data: novoUsuario, error: insertErr } = await admin
      .from("usuarios")
      .insert({
        auth_user_id: inviteData.user.id,
        codigo,
        nome: nome.trim(),
        email: email.toLowerCase().trim(),
        perfil,
        status_acesso: "CONVIDADO",
        ativo: true,
      })
      .select()
      .single();

    if (insertErr) return json({ error: `Erro ao criar usuário: ${insertErr.message}` }, 500);

    // 10. Vínculos com centros de custo
    if (centros_custo.length > 0) {
      const vinculosCentros = centros_custo.map((c: { centro_custo_id: string; papel_no_centro?: string }) => ({
        usuario_id: novoUsuario.id,
        centro_custo_id: c.centro_custo_id,
        papel_no_centro: c.papel_no_centro ?? "MEMBRO",
        ativo: true,
      }));
      const { error: vcErr } = await admin.from("usuario_centros_custo").insert(vinculosCentros);
      if (vcErr) console.error("Erro vínculos centros:", vcErr.message);
    }

    // 11. Vínculos com cartões
    if (cartoes.length > 0) {
      const vinculosCartoes = (cartoes as string[]).map((cartao_id) => ({
        usuario_id: novoUsuario.id,
        cartao_id,
        ativo: true,
      }));
      const { error: cartErr } = await admin.from("usuario_cartoes").insert(vinculosCartoes);
      if (cartErr) console.error("Erro vínculos cartões:", cartErr.message);
    }

    return json({
      success: true,
      message: `Convite enviado para ${email}`,
      usuario: novoUsuario,
    });
  } catch (err) {
    return json({ error: `Erro interno: ${(err as Error).message}` }, 500);
  }
});
