// Supabase Edge Function: send-report
// Sends a job report by e-mail through Gmail SMTP on behalf of a signed-in app user.
// Secrets (Edge Functions -> Secrets): GMAIL_USER, GMAIL_APP_PASSWORD, SENDER_NAME (optional).
import nodemailer from "npm:nodemailer@6.9.16";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const EMAIL = /^[^\s@,;]+@[^\s@,;]+\.[^\s@,;]+$/;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  // Only signed-in users of the app may send: check the caller's access token with the auth server.
  const token = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
  const apikey = req.headers.get("apikey") || Deno.env.get("SUPABASE_ANON_KEY") || "";
  const who = await fetch(`${Deno.env.get("SUPABASE_URL")}/auth/v1/user`, {
    headers: { Authorization: `Bearer ${token}`, apikey },
  });
  if (!who.ok) return json({ error: "not_signed_in" }, 401);
  const user = await who.json();
  if (!user || !user.id) return json({ error: "not_signed_in" }, 401);

  let body: { to?: string; subject?: string; text?: string; csv?: string; csvName?: string };
  try { body = await req.json(); } catch { return json({ error: "bad_request" }, 400); }

  const to = String(body.to || "").split(/[,;]/).map((s) => s.trim()).filter(Boolean);
  if (!to.length || to.length > 5 || !to.every((a) => EMAIL.test(a))) return json({ error: "bad_recipient" }, 400);
  const subject = String(body.subject || "Jobbrapport").slice(0, 200);
  const text = String(body.text || "");
  if (!text || text.length > 200_000) return json({ error: "bad_text" }, 400);

  const gmailUser = Deno.env.get("GMAIL_USER");
  const gmailPass = Deno.env.get("GMAIL_APP_PASSWORD");
  if (!gmailUser || !gmailPass) return json({ error: "sender_not_configured" }, 500);

  try {
    const transporter = nodemailer.createTransport({
      host: "smtp.gmail.com",
      port: 465,
      secure: true,
      auth: { user: gmailUser, pass: gmailPass.replace(/\s+/g, "") },
    });
    await transporter.sendMail({
      from: { name: Deno.env.get("SENDER_NAME") || "Tess Mobilservice", address: gmailUser },
      to,
      replyTo: user.email || undefined,
      subject,
      text,
      attachments: body.csv
        ? [{ filename: String(body.csvName || "ordre.csv").slice(0, 120), content: String(body.csv), contentType: "text/csv; charset=utf-8" }]
        : [],
    });
    return json({ ok: true });
  } catch (e) {
    return json({ error: "send_failed", detail: String((e as Error)?.message || e) }, 502);
  }
});
