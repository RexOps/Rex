export default {
	defaultIgnores: false,
	helpUrl: 'https://github.com/RexOps/Rex/blob/master/CONTRIBUTING.md#git-workflow',
	rules: {
		'body-leading-blank':   [ 2, 'always', true ],
		'header-max-length':    [ 2, 'always', 50 ],
		'header-case':          [ 2, 'always', 'sentence-case' ],
		'header-full-stop':     [ 2, 'never',  '.' ],
		'body-max-line-length': [ 2, 'always', 72 ]
	},
}
