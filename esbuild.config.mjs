import * as esbuild from "esbuild";
import sveltePlugin from "esbuild-svelte";
import { copyFileSync, mkdirSync, existsSync, cpSync } from "fs";
import { dirname } from "path";

const isWatch = process.argv.includes("--watch");
const srcDir = "src";
const outDir = "dist";

/** Copy static assets (manifest, HTML, CSS, icons, img) to dist/ */
function copyStaticAssets() {
  const assets = [
    ["src/manifest.json", "dist/manifest.json"],
    ["src/ui/popup/popup.html", "dist/ui/popup/popup.html"],
    ["src/ui/options/options.html", "dist/ui/options/options.html"],
    ["src/ui/shared/styles.css", "dist/ui/shared/styles.css"],
  ];

  for (const [src, dest] of assets) {
    if (!existsSync(src)) continue;
    const dir = dirname(dest);
    mkdirSync(dir, { recursive: true });
    copyFileSync(src, dest);
  }

  if (existsSync("src/icons")) {
    mkdirSync("dist/icons", { recursive: true });
    cpSync("src/icons", "dist/icons", { recursive: true });
  }

  if (existsSync("src/img")) {
    mkdirSync("dist/img", { recursive: true });
    cpSync("src/img", "dist/img", { recursive: true });
  }
}

/** @type {esbuild.Plugin} */
const copyPlugin = {
  name: "copy-static-assets",
  setup(build) {
    build.onEnd(() => {
      copyStaticAssets();
    });
  },
};

const buildOptions = {
  entryPoints: [
    { in: `${srcDir}/background/Main.res.mjs`, out: "background" },
    { in: `${srcDir}/ui/popup/popup.ts`, out: "ui/popup/popup" },
    { in: `${srcDir}/ui/options/options.ts`, out: "ui/options/options" },
  ],
  bundle: true,
  outdir: outDir,
  format: "iife",
  target: "firefox128",
  platform: "browser",
  sourcemap: isWatch ? "inline" : false,
  minify: !isWatch,
  conditions: ["svelte", "browser"],
  plugins: [
    sveltePlugin({
      compilerOptions: {
        css: "injected",
      },
    }),
    copyPlugin,
  ],
};

if (isWatch) {
  const ctx = await esbuild.context(buildOptions);
  await ctx.watch();
  console.log("Watching for changes...");
} else {
  await esbuild.build(buildOptions);
  console.log("Build complete.");
}
