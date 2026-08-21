window.authCookies = {
  setDoctorSession: async function (
    token,
    refreshToken,
    tokenExpires,
    refreshExpires,
  ) {
    try {
      const response = await fetch("/auth/doctor-cookie", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          token: token,
          refreshToken: refreshToken,
          tokenExpires: tokenExpires,
          refreshExpires: refreshExpires,
        }),
      });

      if (!response.ok) {
        throw new Error(`Failed to set cookies: ${response.status} ${response.statusText}`);
      }

      await new Promise(resolve => setTimeout(resolve, 100));
      
      return true;
    } catch (error) {
      console.error("[AuthCookies] Error setting doctor session:", error);
      throw error;
    }
  },
  
  clearDoctorSession: async function () {
    try {
      const response = await fetch("/auth/doctor-cookie/clear", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
      });

      if (!response.ok) {
        throw new Error(`Failed to clear cookies: ${response.status} ${response.statusText}`);
      }

      return true;
    } catch (error) {
      console.error("[AuthCookies] Error clearing doctor session:", error);
      throw error;
    }
  },
};
