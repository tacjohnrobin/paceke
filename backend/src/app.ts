import Fastify from "fastify";

const app = Fastify({
  logger: true,
});

app.get("/", async () => {
  return { status: "ok" };
});

app.listen({ port: 3333 }, (err) => {
  if (err) {
    app.log.error(err);
    process.exit(1);
  }
  console.log(" http://localhost:3333");
});
