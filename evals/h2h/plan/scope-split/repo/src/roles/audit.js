export const canView = (user) => user.role === 'clerk' || user.role === 'manager';
