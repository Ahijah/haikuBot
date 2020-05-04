{
	##############################################
	# Base Config
	##############################################
	database => 'haiku.db',
	dbuser => '',
	dbpass => '',
	botOwner => 'Xafloc',
	URL => 'https://apps.rego.ai/HaikuBot',
	# APIURL => 'https://api.datamuse.com/words?md=s&max=1&sp=',
	# Be sure to escape special characters
	trigger => '?haiku', 
	triggerStats => '?haikustats',
	triggerVote => '?haikuvote',
	triggerHelp => '?haikuhelp',
	triggerList => '?haikulist',
	triggerTop => '?haikutop',
	trigger5 => '?haiku5',
	trigger7 => '?haiku7',

	##############################################
	# Profanity Settings
	##############################################
	degree => 'definite', # Or 'ambiguous'

	##############################################
	# IRC Settings
	##############################################
	ircServer => 'irc.darkscience.net',
	ircPort => '6697',
	ircChannels => ['#haiku'],
	#ircChannels => ['#bots','#haiku'],
	ircNick => 'haikuBot',
	ircPass => '',
	ircName => 'Haiku Bot',
	ircSSL => '1', # Or '0'

	##############################################
	# Help text
	##############################################
	helpText => "Usage: \n" .
		"?haiku - (Generates a random Haiku)\n" .
		"?haikustats - (Displays HaikuBot statistics)\n" .
		"?haikuvote <Haiku ID> - (Upvotes Haiku matching ID - Max one vote per user/haiku)\n" .
		"?haiku5 <5 syllable haiku line> - (Creates 5 syllable haiku line)\n" .
		"?haiku7 <5 syllable haiku line>|<1 or 3> - (Creates 5 syllable haiku line w/ forced 1 or 3 position)\n" .
		"  E.g. !haiku5 this must be the end|3\n" .
		"?haiku7 <7 syllable haiku line> - (Creates a new 7 syllable haiku line)\n" .
		"?haikutop - (PMs the top 5 voted randomly generated haiku)\n" .
		" --Web List of Generated Haiku: https://apps.rego.ai/HaikuBot",
}