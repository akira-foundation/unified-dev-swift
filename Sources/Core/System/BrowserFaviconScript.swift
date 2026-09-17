import Foundation

public enum BrowserFaviconScript {
    private static let selector = """
        link[rel~='icon'], link[rel~='apple-touch-icon'], link[rel~='apple-touch-icon-precomposed']
        """

    public static let links = """
        const found = document.querySelectorAll("\(selector)");
        const out = [];
        for (let i = 0; i < found.length && out.length < limit * 4; i += 1) {
          const link = found[i];
          out.push(
            String(link.rel || "").slice(0, chars),
            String(link.getAttribute("sizes") || "").slice(0, chars),
            String(link.type || "").slice(0, chars),
            String(link.href || "").slice(0, chars)
          );
        }
        return out;
        """

    public static let image = """
        const found = document.querySelectorAll("\(selector)");
        const link = found[index];
        if (!link) { return null; }
        const href = String(link.href || "").slice(0, chars);
        if (!href) { return null; }

        const image = new Image();
        image.crossOrigin = "anonymous";
        const loaded = await new Promise((resolve) => {
          image.onload = () => resolve(true);
          image.onerror = () => resolve(false);
          setTimeout(() => resolve(false), timeout);
          image.src = href;
        });
        if (!loaded) { return null; }

        let width = image.naturalWidth || image.width || 0;
        let height = image.naturalHeight || image.height || 0;
        // An SVG with no width and no height of its own measures zero, and something zero wide
        // draws nothing. It scales to whatever it is asked for, so it is asked for all of it.
        if (width <= 0 || height <= 0) { width = size; height = size; }

        const canvas = document.createElement("canvas");
        canvas.width = size;
        canvas.height = size;
        const context = canvas.getContext("2d");
        if (!context) { return null; }

        // Letterboxed rather than stretched. A wordmark four times as wide as it is tall is a real
        // thing to find in a `<link rel=icon>`, and squashing it would put a distorted picture in
        // the strip instead of a small one.
        const scale = Math.min(size / width, size / height);
        const drawnWidth = Math.max(1, Math.round(width * scale));
        const drawnHeight = Math.max(1, Math.round(height * scale));
        context.drawImage(
          image,
          Math.round((size - drawnWidth) / 2),
          Math.round((size - drawnHeight) / 2),
          drawnWidth,
          drawnHeight
        );

        let encoded = "";
        try {
          encoded = canvas.toDataURL("image/png");
        } catch (error) {
          return null;
        }
        return [href, encoded];
        """
}
