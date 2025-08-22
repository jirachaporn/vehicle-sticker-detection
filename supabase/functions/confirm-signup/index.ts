Deno.serve((req: Request) => {
  try {
    const url = new URL(req.url);
    const errorCode = url.searchParams.get("error_code");
    const errorDesc = url.searchParams.get("error_description");

    if (errorCode) {
      return new Response(
        `❌ Email confirmation failed (${errorCode})${errorDesc ? `: ${errorDesc}` : ""}`,
        { status: 400, headers: { "Content-Type": "text/plain; charset=utf-8" } }
      );
    }
    return new Response("✅ Confirmed successfully, The system is now available for use.", {
      status: 200,
      headers: { "Content-Type": "text/plain; charset=utf-8" },
    });
  } catch (e) {
    return new Response(`❌ Unexpected error: ${String(e)}`, {
      status: 500, headers: { "Content-Type": "text/plain; charset=utf-8" },
    });
  }
});
