class Rules

	#this will determine if the np's match in number
	#give higher weight to npModel2 being a pronoun
	def self.matchPlurality(npModel1, npModel2)
		if npModel1.plurality == true && npModel2.plurality == true && npModel2.pronounType != "none"
			return -9999
		end
	    if(npModel1.plurality == npModel2.plurality)
			return -999
	    else
			return 0
	    end
	end

	def self.matchGender(npModel1, npModel2)
	    if(npModel1.gender != "UNKNOWN" &&
	       npModel2.gender != "UNKNOWN")
		if(npModel1.gender != npModel2.gender)
		    return false
		else
		    return true
		end
	    end
	end

	def self.articleRule(npModel)
	   if(!(npModel.appositive))
	     if(npModel.article == "a" || npModel.article == "an" || npModel.article == "some")
		return 0	
	     end
	   end 
		return 1	
	end

	def self.searchForComma(endIdx, sentence)
    	#check to see if any of the existing words have a comma or a period
    	return
   		endCharFound = false
    	commaFound = false
    	endChars = [".", "!", "?"]

    	for i in (endIdx+1)...(sentence.length)
    		word = sentence.sent[i]
    		word.chars.to_a.each do |c|
    			if endChars.include? c
    				endCharFound = true
    				break
    			elsif c == ","
    				commaFound = true
    				break
    			end
    		end

    		if endCharFound || commaFound
    			break
    		end
    	end

    	if endCharFound
    		"."
    	elsif commaFound
    		","
    	else
    		""
    	end
	end

	def self.appositiveRule(npModel, sentIdx, sentences)
		if npModel.startIdx > 0
			prevWord = npModel.sent.sent[npModel.startIdx-1]
			#only going to get the ones with a single comma...
    		if prevWord == ","
    			#let's check if the next word after is a comma too...

    			#check to see if any of the existing words have a comma or a period
    			res = searchForComma(npModel.endIdx, npModel.sent)

    			if res == "." || sentIdx+1 >= sentences.length
    				return false	
    			end

    			#get the next sentence, do the same thing
    			if res == ""
    				nextSentence = sentences[sentIdx+1]
    				#looking for a comma, if it exists we're good
    				res = searchForComma(-1, nextSentence)
    				if res != ","
    					return false
    				end
    			end

    			#if we get this far, we know it's an appositive
    			#is the prev word part of an NP?
       			nextNp = npModel.sent.npModels.select{|t| t.endIdx == npModel.startIdx - 2}

        		if nextNp.length == 1
         			
         			Ncrf.log "appositiveSuccess #{nextNp[0].phrase} <- #{npModel.phrase}"
          			npModel.ref = nextNp[0]
          			nextNp[0].included = true
          			return true
        		end
      		end
		end

		return false
	end

	def self.wordsSubstring(npModel, sentIdx, sentences)
		if npModel.pronounType != "none"
			return
		end

		prevSentences = []
	
		for i in 0...sentIdx
		  prevSentences.push sentences[i]
		end
	
		#starting at the beginning, find the first np with any sort of match to our current phrase
		badWords = ["a", "an", "the", "of", "these", "mr", "mr.", "mrs", "mrs."]
		npPhrase = npModel.phrase.split(/\s+/)
		regexs = []
		npPhrase.select{|t| !badWords.include?(t)}.each do |word|
		  regexs.push word
		end
	
		match = false

		prevSentences.reverse!

		foundMatches = []

		dist = 0
		
		Ncrf.log "substring #{npModel.phrase}:"
		prevSentences.each do |prevSent|
	  
		  prevSent.npModels.select{|t| t.pronounType == 'none'}.each do |acceptableNp|
		  	Ncrf.log "substring comparing #{acceptableNp.phrase}"
		  	#first, headnouns same? success!
		  	if Utilities.editDistance(npModel.headNoun, acceptableNp.headNoun) <= 1
		  		  Ncrf.log "matching <#{acceptableNp.phrase}> <- <#{npModel.phrase}>"
				  Ncrf.log ""
				  #this acceptableNp is a match
				  acceptableNp.included = true
				  npModel.ref = acceptableNp

				  return true
		  	end
			
			foundCount = 0

			#getting rid of chars that aren't A-Z0-9
			acceptableWords = acceptableNp.phrase
								.gsub(/[^0-9A-Za-z]/, " ")
								.split(/\s+/)
								.select{|t| !badWords.include?(t)}

			regexs.each do |regex|

			 	acceptableWords.each do |word|
			
					if Utilities.editDistance(regex, word) <= 1
						foundCount = foundCount + 1
					end
			  	end
			end

			if foundCount > 0
		  		score = (foundCount.to_f / acceptableWords.length.to_f)

		  		kvp = { :np => acceptableNp, :acc =>  score }
		  		
		  		Ncrf.log "\tpushing #{acceptableNp.phrase} with #{kvp[:acc]}"
		  		foundMatches.push kvp
		  	end

			dist = dist + 1
	 	 end
		end

		if foundMatches.length > 0
			bestMatch = foundMatches.sort{|a,b| b[:acc] <=> a[:acc] }
	
			Ncrf.log "matching <#{bestMatch[0][:np].phrase}> <- <#{npModel.phrase}>"
			Ncrf.log ""
			#this acceptableNp is a match
			bestMatch[0][:np].included = true
			npModel.ref = bestMatch[0][:np]

			true
		else
			Ncrf.log ""
			false
		end
	end

	#1 Incompatibility function: 1 if both are proper names, but mismatch on every word; else 0
	def self.properNames(npModel1, npModel2)
		if npModel1 != nil && npModel2 != nil
			if npModel1.properName && npModel2.properName
				compat = false

				np1Words = npModel1.phrase.split(/\s+/)
				np2Words = npModel2.phrase.split(/\s+/)
				
				np1Words.each do |word1|
					
					np2Words.each do |word2|
						if word1 == word2
							compat = true
						end

						if compat
							break
						end
					end

					if compat
						break
					end
				end

				if !compat
					return true
				end
			end
		end
		return false
	end

	def self.pronounTypes(npModel1, npModel2)
		if npModel1.pronounType != "none" && npModel2.pronounType == "none"
			0
		else
			1
		end
	end

	def self.mismatchWords(npModel1, npModel2)
		firstWords = npModel1.phrase.split(/\s+/)
		secondWords = npModel2.phrase.split(/\s+/)

		#going to go with the larger one, cycle through it
		largerCollection = firstWords.length < secondWords.length ? secondWords : firstWords
		smallerCollection = firstWords.length < secondWords.length ? firstWords : secondWords

		largerSize = largerCollection.length
		smallerSize = smallerCollection.length

		mismatchCount = 0
		
		for i in 0...largerSize
			if i < smallerSize
				
				if largerCollection[i] != smallerCollection[i] && 
					npModel1.pronounType == "none" && 
					npModel2.pronounType == "none"
					mismatchCount = mismatchCount + 1
				end
			else
				mismatchCount = mismatchCount + 1
			end
		end
		(mismatchCount.to_f) / (largerSize.to_f)
	end

	def self.headnounsDiffer(npModel1, npModel2)
		if npModel1.headNoun != npModel2.headNoun
			1
		else
			0
		end
	end

	def self.subsume(npModel1, npModel2)
		if npModel1.phrase.length <= 1 || npModel2.phrase.length <= 1
			return 0
		end

		#special case for "it"

		firstPhrase = npModel1.phrase.downcase
		secondPhrase = npModel2.phrase.downcase

		if firstPhrase == "it" && secondPhrase == "it"
			return -9999
		end

		if npModel1.pronounType != "none" || npModel2.pronounType != "none"
			return 0
		end

		badWords = ["a", "an", "the", "of"]
		if badWords.include?(secondPhrase) || badWords.include?(firstPhrase)
			return 0
		end

		res = firstPhrase.index secondPhrase
		res != nil ? -9999 : 0
	end

	def self.imerule(npModel1, npModel2)
		norm1 = npModel1.phrase.downcase.lstrip.rstrip
		norm2 = npModel2.phrase.downcase.lstrip.rstrip

		if norm1 == "me" && norm2 == "i"
			#puts "IMERULE -> <#{norm1}> <#{norm2}>"
			return -9999
		end

		if norm1 == "i" && norm2 == "me"
			#puts "IMERULE -> <#{norm1}> <#{norm2}>"
			return -9999
		end

		return 0
	end

	def self.specialThisRule(npModel1, npModel2)
		if npModel2.phrase.downcase == "this" && npModel1.pronounType == "none"
			dist = npModel1.position - npModel2.position
			#giving 2 a shot
			if dist <= 2
				return -999
			end
		end
		return 0
	end

 def self.findCorrectAnt(npModel, sentIdx, sentences)
	#right now, just going to find the first np in the preceding sentence

	#ya, there's probably a more efficient way to get this. later...
	allNps = []
	sentences.each do |sent|
		sent.npModels.each do |np|
			allNps.push np
		end
	end

	lastNp = allNps.sort{|a, b| b.position <=> a.position}.first
	maxDistance = lastNp.position

	prevNps = []
	#puts "getting prev nps for sendIdx #{sentIdx} - #{npModel.phrase}"
	
	#get the preceding ones
	sentences.select{|t| t.sentIdx < sentIdx}.each do |sentence|
		sentence.npModels.each do |np|
			prevNps.push np
		end
	end

	#get the preceding ones from the current sentence
	npModel.sent.npModels.select{|t| t.startIdx < npModel.startIdx }.each do |prevNp|
		prevNps.push prevNp
	end

	prevNps.sort!{|a,b| b.position <=> a.position }

	#going to use a has to represent the result... { npModel, value }

	results = []

	Ncrf.log "comparing #{npModel} with:"

	prevNps.each do |prevNp|
		score = 0
		subsumeScore = subsume(npModel, prevNp)
		reverseSubsumeScore = subsume(prevNp, npModel)

		#we don't need to compare anymore if this is true
		#mismatch words score
		score1 = mismatchWords(npModel, prevNp) * 10
		#head noun differ score
		score2 = headnounsDiffer(npModel, prevNp)
		#difference in position score, testing out heavy emphasis on it...
		score3 = (npModel.position - prevNp.position).abs.to_f / maxDistance.to_f * 5000
		#pronoun score
		score4 = pronounTypes(npModel, prevNp)
		#plurality score
		#shouldn't this be ? 0 : 999? or maybe i don't understand ruby's ternary op's-ben
		#oh i see, your doing a change from greatest to least weighted np matching
		score5 = matchPlurality(npModel, prevNp)
		#proper names score
		score6 = properNames(npModel, prevNp) == true ? 999 : 0
		#gender score
		score7 = matchGender(npModel, prevNp) == true ? 999 : 0
		#article score	
		score8 = articleRule(prevNp)
		#special this rule
		specialThisScore = specialThisRule(npModel, prevNp)

		totalScore = score1 + score2 + score3 + score4 + score5 + score6 + score7 + score8

		totalScore = score1 + score2 + score3 + score4 + score5 + score6
		totalScore = totalScore + subsumeScore
		totalScore = totalScore + reverseSubsumeScore
		totalScore = totalScore + imerule(npModel, prevNp)
		totalScore = totalScore + specialThisScore

		tmpKvp = {:np => prevNp, :score => totalScore }
		results.push tmpKvp
		
		Ncrf.log "totalScore: #{totalScore} #{prevNp}"
		
	end

	foundNp = results.sort{|a, b| a[:score] <=> b[:score] }.first

	if foundNp != nil
		
		Ncrf.log "assigning <#{foundNp[:np].phrase} #{foundNp[:np].id}> to <#{npModel.phrase} #{npModel.id}> with score of #{foundNp[:score]}"
		Ncrf.log ""
		
		foundNp[:np].included = true
		npModel.ref = foundNp[:np]
	end
  end
end
