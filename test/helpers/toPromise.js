module.exports = func =>
  (...args) =>
    new Promise((resolve, reject) =>
      func(...args, (error, data) => error ? reject(error) : resolve(data)));
