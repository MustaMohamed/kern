// A thin wrapper over the driver; tests swap it with an in-memory fake.
export const db = { all: () => [], run: () => ({ changes: 0 }) };
