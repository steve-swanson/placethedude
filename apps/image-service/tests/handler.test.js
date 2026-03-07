const test = require("node:test");
const assert = require("node:assert/strict");

const { parseRequestPath, buildImageKey } = require("../src/handler");

test("parseRequestPath accepts img path prefix", () => {
  assert.deepEqual(parseRequestPath("/img/300/200"), {
    specialHandler: "",
    width: 300,
    height: 200
  });
});

test("parseRequestPath accepts optional special handler", () => {
  assert.deepEqual(parseRequestPath("/img/g/320/180"), {
    specialHandler: "g",
    width: 320,
    height: 180
  });
});

test("parseRequestPath still parses legacy direct lambda paths", () => {
  assert.deepEqual(parseRequestPath("/640/360"), {
    specialHandler: "",
    width: 640,
    height: 360
  });
});

test("parseRequestPath rejects unsupported paths", () => {
  assert.throws(() => parseRequestPath("/assets/logo.png"), /Unsupported path/);
});

test("buildImageKey pads image numbers", () => {
  assert.equal(buildImageKey(7, { prefix: "thedude-", suffix: ".jpg", padding: 2 }), "thedude-07.jpg");
});
