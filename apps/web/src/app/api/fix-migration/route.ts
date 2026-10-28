export async function POST(request: Request) {
  try {
    const { familyId } = await request.json();

    if (!familyId) {
      return Response.json(
        { error: "Missing familyId" },
        { status: 400 }
      );
    }

    // Verify auth header
    const authHeader = request.headers.get("authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return Response.json(
        { error: "Missing or invalid authorization" },
        { status: 401 }
      );
    }

    const token = authHeader.substring(7);

    // Call the fixMigrationDateFormats cloud function directly from backend
    // This avoids CORS issues since the request comes from server, not browser
    const projectId = process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID;
    
    if (!projectId) {
      return Response.json(
        { error: "Firebase project not configured" },
        { status: 500 }
      );
    }

    const response = await fetch(
      `https://us-central1-${projectId}.cloudfunctions.net/fixMigrationDateFormats`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${token}`,
        },
        body: JSON.stringify({ data: { familyId } }),
      }
    );

    if (!response.ok) {
      const error = await response.text();
      console.error(`Cloud function error: ${error}`);
      throw new Error(`Cloud function failed with status ${response.status}`);
    }

    const result = await response.json();
    return Response.json(result);
  } catch (error: any) {
    console.error("Fix migration error:", error);
    return Response.json(
      { error: error.message || "Fix migration failed" },
      { status: 500 }
    );
  }
}
