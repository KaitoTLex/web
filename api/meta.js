// Returns the git SHA injected by Vercel at deploy time.
// VERCEL_GIT_COMMIT_SHA is automatically available in all Vercel deployments.
module.exports = (req, res) => {
  res.setHeader('Cache-Control', 'public, s-maxage=86400');
  res.status(200).json({
    sha: process.env.VERCEL_GIT_COMMIT_SHA || '',
  });
};
