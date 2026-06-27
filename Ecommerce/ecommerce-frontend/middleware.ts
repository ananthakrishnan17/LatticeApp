import { NextRequest, NextResponse } from "next/server";

/**
 * Protect all /admin/* routes (except /admin/login) so that unauthenticated
 * visitors are redirected to the admin login page.
 *
 * NOTE: JWT validation is enforced by the backend on every API call.
 * This middleware only performs a lightweight client-side token-presence check
 * to give a better UX (redirect before showing a broken admin page).
 */
export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  if (pathname.startsWith("/admin") && pathname !== "/admin/login") {
    const token = request.cookies.get("ec_token")?.value;
    if (!token) {
      const loginUrl = new URL("/admin/login", request.url);
      loginUrl.searchParams.set("from", pathname);
      return NextResponse.redirect(loginUrl);
    }
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/admin/:path*"],
};
