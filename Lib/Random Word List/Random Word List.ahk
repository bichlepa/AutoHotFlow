;This script contains a wordlist.

RandomWordList_Adjectives:=["big", "small", "tall", "large", "great", "little", "noisy", "silent", "tired", "happy", "sad", "boring", "stupid", "silly", "smart", "clever", "bright", "dark", "shiny", "liquid", "hard", "soft", "tough", "light", "lazy", "eager", "dilligent", "horrible", "beautiful", "closed", "open", "attractive", "anxious", "charming", "evil", "friendly","greedy", "serious", "fast", "slow", "curious", "weak", "strong", "strange", "odd", "funny", "surprised", "dirty", "clean", "black", "white", "yellow", "red", "green", "blue", "dangerous", "safe", "early", "late", "empty", "full", "flying", "standing", "floating", "sick", "left", "right"]
RandomWordList_Nouns:=["house", "door", "window", "ladder", "stairs", "chair", "cupboard", "table", "wall", "car", "boat", "ship", "bus", "train", "bicycle", "plane", "soil", "apple", "banana", "bird", "ape", "cat", "dog", "fly", "horse", "bottle", "box", "tree", "bush", "grass", "branch", "potato", "breakfast", "lunch", "dinner", "morning", "evening", "night", "cake", "cheese", "salad", "sadnwich", "chocolate", "coffee", "ice", "milk", "city", "clock", "eye", "hand", "head", "leg", "nose", "ear", "mouth", "finger", "joke", "message", "paper", "pencil", "picture", "rain", "snow", "water", "rock", "air"]

randomAdjective()
{
	global RandomWordList_Adjectives, RandomWordList_Nouns
	random, randomvalue, 1, % RandomWordList_Adjectives.maxindex()
	return % RandomWordList_Adjectives[randomvalue]
}
randomNoun()
{
	global RandomWordList_Adjectives, RandomWordList_Nouns
	random, randomvalue, 1, % RandomWordList_Nouns.maxindex()
	return % RandomWordList_Adjectives[randomvalue]
}
randomPhrase()
{
	global RandomWordList_Adjectives, RandomWordList_Nouns
	random, randomvalue1, 1, % RandomWordList_Adjectives.maxindex()
	random, randomvalue2, 1, % RandomWordList_Nouns.maxindex()
	return % RandomWordList_Adjectives[randomvalue1] " " RandomWordList_Nouns[randomvalue2]
}