const stripe = require("../config/stripe");
const https = require("https");

/**
 * Serve Stripe files (logo, icon) by proxying from Stripe
 */
async function serveStripeFile(req, res) {
  const { fileId } = req.params;

  if (!fileId) {
    return res.status(400).json({ error: "File ID is required" });
  }

  try {
    const file = await stripe.files.retrieve(fileId);

    if (!file) {
      return res.status(404).json({ error: "File not found" });
    }

    const fileUrl = file.links?.data?.[0]?.url;
    if (!fileUrl) {
      return res.status(404).json({ error: "File URL not available" });
    }

    https
      .get(fileUrl, (fileResponse) => {
        if (fileResponse.statusCode !== 200) {
          return res
            .status(500)
            .json({ error: "Failed to download file from Stripe" });
        }

        res.set({
          "Content-Type": file.type || "application/octet-stream",
          "Content-Disposition": `inline; filename="${
            file.filename || fileId
          }"`,
          "Cache-Control": "public, max-age=3600",
        });

        fileResponse.pipe(res);
      })
      .on("error", (error) => {
        console.error("Error downloading file from Stripe:", error);
        res.status(500).json({ error: "Failed to download file" });
      });
  } catch (error) {
    console.error("Failed to serve Stripe file:", error.message);

    if (error.type === "StripeInvalidRequestError") {
      return res.status(404).json({ error: "File not found" });
    }

    res.status(500).json({ error: "Internal server error" });
  }
}

module.exports = {
  serveStripeFile,
};
