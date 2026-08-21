// Admin authentication cookie management via JS interop
window.authCookies = {
  setAdminSession: async function (
    token,
    refreshToken,
    tokenExpires,
    refreshExpires,
  ) {
    const response = await fetch("/auth/admin-cookie", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        token: token,
        refreshToken: refreshToken,
        tokenExpires: tokenExpires,
        refreshExpires: refreshExpires,
      }),
    });

    if (!response.ok)
      throw new Error(`Failed to set cookies: ${response.status}`);

    // Small delay to ensure cookies are set before next request
    await new Promise((resolve) => setTimeout(resolve, 100));
    return true;
  },

  clearAdminSession: async function () {
    const response = await fetch("/auth/admin-cookie/clear", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
    });

    if (!response.ok)
      throw new Error(`Failed to clear cookies: ${response.status}`);

    return true;
  },
};
