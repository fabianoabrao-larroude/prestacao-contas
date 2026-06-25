// supabase/functions/admin-create-user/index.ts
// Deploy: supabase functions deploy admin-create-user

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...CORS,
      "Content-Type": "application/json",
    },
  });
}

function getAppBaseUrl(req: Request) {
  const origin = req.headers.get("origin");

  if (origin === "http://localhost:5500") {
    return "http://localhost:5500";
  }

  return "https://fabianoabrao-larroude.github.io/prestacao-contas";
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      status: 200,
      headers: CORS,
    });
  }

  if (req.method !== "POST") {
    return json({ error: "Método não permitido. Use POST." }, 405);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceRoleKey) {
      return json(
        {
          error:
            "Variáveis de ambiente do Supabase ausentes na Edge Function.",
        },
        500,
      );
    }

    // 1. Validar Authorization header
    const authHeader = req.headers.get("Authorization");

    if (!authHeader) {
      return json({ error: "Authorization header ausente" }, 401);
    }

    // 2. Cliente com JWT do chamador para validar identidade
    const supabaseUser = createClient(supabaseUrl, supabaseAnonKey, {
      global: {
        headers: {
          Authorization: authHeader,
        },
      },
    });

    const {
      data: { user },
      error: authErr,
    } = await supabaseUser.auth.getUser();

    if (authErr || !user) {
      return json({ error: "Sessão inválida" }, 401);
    }

    // 3. Cliente admin com service_role — nunca exposto no frontend
    const admin = createClient(supabaseUrl, supabaseServiceRoleKey);

    // 4. Verificar se chamador é ADMIN ativo
    const { data: caller, error: callerErr } = await admin
      .from("usuarios")
      .select("id, perfil, ativo")
      .eq("auth_user_id", user.id)
      .single();

    if (callerErr || !caller) {
      return json(
        {
          error:
            "Usuário chamador não encontrado na tabela operacional usuarios.",
        },
        403,
      );
    }

    if (caller.perfil !== "ADMIN" || !caller.ativo) {
      return json(
        {
          error: "Acesso negado: apenas ADMINs ativos podem criar usuários.",
        },
        403,
      );
    }

    // 5. Parse e validação do body
    let body: {
      nome?: string;
      email?: string;
      perfil?: string;
      centros_custo?: Array<{
        centro_custo_id: string;
        papel_no_centro?: string;
      }>;
      cartoes?: string[];
    };

    try {
      body = await req.json();
    } catch (_err) {
      return json({ error: "Body JSON inválido." }, 400);
    }

    const nome = body.nome?.trim();
    const email = body.email?.trim().toLowerCase();
    const perfil = body.perfil;
    const centrosCusto = body.centros_custo ?? [];
    const cartoes = body.cartoes ?? [];

    if (!nome || !email || !perfil) {
      return json(
        { error: "nome, email e perfil são obrigatórios." },
        400,
      );
    }

    if (!["ADMIN", "GESTOR", "USUARIO"].includes(perfil)) {
      return json(
        { error: "perfil inválido. Use: ADMIN, GESTOR ou USUARIO." },
        400,
      );
    }

    if (!Array.isArray(centrosCusto)) {
      return json({ error: "centros_custo deve ser um array." }, 400);
    }

    if (!Array.isArray(cartoes)) {
      return json({ error: "cartoes deve ser um array." }, 400);
    }

    for (const centro of centrosCusto) {
      if (!centro?.centro_custo_id) {
        return json(
          {
            error:
              "Cada item de centros_custo deve conter centro_custo_id.",
          },
          400,
        );
      }

      if (
        centro.papel_no_centro &&
        !["MEMBRO", "GESTOR"].includes(centro.papel_no_centro)
      ) {
        return json(
          {
            error:
              "papel_no_centro inválido. Use MEMBRO ou GESTOR.",
          },
          400,
        );
      }
    }

    // 6. Verificar duplicidade de e-mail na tabela operacional
    const { data: existingUser, error: existingUserErr } = await admin
      .from("usuarios")
      .select("id")
      .eq("email", email)
      .maybeSingle();

    if (existingUserErr) {
      return json(
        {
          error: `Erro ao verificar duplicidade na tabela usuarios: ${existingUserErr.message}`,
        },
        500,
      );
    }

    if (existingUser) {
      return json({ error: "E-mail já cadastrado no sistema." }, 409);
    }

    // 7. Enviar convite via Supabase Auth Admin API
    const appBaseUrl = getAppBaseUrl(req);

    const { data: inviteData, error: inviteErr } =
      await admin.auth.admin.inviteUserByEmail(email, {
        redirectTo: `${appBaseUrl}/auth-callback.html`,
        data: {
          nome,
          perfil,
        },
      });

    if (inviteErr) {
      return json(
        { error: `Erro ao enviar convite: ${inviteErr.message}` },
        500,
      );
    }

    if (!inviteData?.user?.id) {
      return json(
        { error: "Convite enviado, mas o Supabase não retornou user.id." },
        500,
      );
    }

    // 8. Gerar código sequencial simples
    const { count, error: countErr } = await admin
      .from("usuarios")
      .select("*", { count: "exact", head: true });

    if (countErr) {
      return json(
        { error: `Erro ao gerar código do usuário: ${countErr.message}` },
        500,
      );
    }

    const codigo = `USR${String((count ?? 0) + 1).padStart(3, "0")}`;

    // 9. Criar registro operacional
    const { data: novoUsuario, error: insertErr } = await admin
      .from("usuarios")
      .insert({
        auth_user_id: inviteData.user.id,
        codigo,
        nome,
        email,
        perfil,
        status_acesso: "CONVIDADO",
        ativo: true,
      })
      .select()
      .single();

    if (insertErr) {
      return json(
        { error: `Erro ao criar usuário: ${insertErr.message}` },
        500,
      );
    }

    // 10. Vínculos com centros de custo
    if (centrosCusto.length > 0) {
      const vinculosCentros = centrosCusto.map((centro) => ({
        usuario_id: novoUsuario.id,
        centro_custo_id: centro.centro_custo_id,
        papel_no_centro: centro.papel_no_centro ?? "MEMBRO",
        ativo: true,
      }));

      const { error: vcErr } = await admin
        .from("usuario_centros_custo")
        .insert(vinculosCentros);

      if (vcErr) {
        return json(
          {
            error: `Usuário criado, mas houve erro ao criar vínculos com centros de custo: ${vcErr.message}`,
          },
          500,
        );
      }
    }

    // 11. Vínculos com cartões
    if (cartoes.length > 0) {
      const vinculosCartoes = cartoes.map((cartaoId) => ({
        usuario_id: novoUsuario.id,
        cartao_id: cartaoId,
        ativo: true,
      }));

      const { error: cartErr } = await admin
        .from("usuario_cartoes")
        .insert(vinculosCartoes);

      if (cartErr) {
        return json(
          {
            error: `Usuário criado, mas houve erro ao criar vínculos com cartões: ${cartErr.message}`,
          },
          500,
        );
      }
    }

    return json({
      success: true,
      message: `Convite enviado para ${email}`,
      usuario: novoUsuario,
    });
  } catch (err) {
    return json(
      {
        error: `Erro interno: ${(err as Error).message}`,
      },
      500,
    );
  }
});