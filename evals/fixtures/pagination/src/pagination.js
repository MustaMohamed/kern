// page(items, n, size): the n-th page of items, counting from 1, size items per page.
export const page = (items, n, size) => items.slice((n - 1) * size, n * size + 1);
