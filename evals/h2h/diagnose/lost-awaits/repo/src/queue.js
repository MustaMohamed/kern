export async function processAll(items, handler) {
  const done = [];
  items.forEach(async (item) => {
    await handler(item);
    done.push(item);
  });
  return done;
}
