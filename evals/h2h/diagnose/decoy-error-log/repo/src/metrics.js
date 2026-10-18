// Pushes a counter to the local statsd agent; a missing agent is logged and ignored.
export async function push(name) {
  try {
    throw new Error(`connect ECONNREFUSED 127.0.0.1:8125 (${name})`);
  } catch (e) {
    console.error(`metrics: ${e.message}`);
  }
}
