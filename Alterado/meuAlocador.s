#********************************************************
#   Implementação de um alocador de memória em assembly.
# 	Anderson Aparecido do Carmo Frasão 			GRr20204069
#	&
# 	Eduardo Gobbo Willi Vasconcellos Gonçalves 	GRR20203892  
#
#  	Software Básico - CI1064
#********************************************************

.section .data
	inicio_heap: 	.quad 0			# valor inicial da heap, antes do iniciaAlocador
	final_heap:		.quad 0			# valor final da heap, em qualquer dado momento
	Block_size:		.quad 4096 # mais facil de ver # tamanho dos blocos alocados, quando heap cheia
	LIVRE: 			.quad 0			# bool que representa um bloco LIVRE
	OCUPA:			.quad 1			# bool que representa um bloco OCUPADO
	MAIOR:			.quad 0
	olhos:			.quad 0			# variavel que contem o ultimo nó analizado
	circular:		.quad 0			# se olhos ja circularam na heap, $1, else $0, usamos pra
	 								# decidir se é preciso aumentar a heap ou nao

	strinit:		.string "\n"
	strnodo:		.string "( %i | %i ).."
	strfinal:		.string "final Heap\n\n"

	strIG:			.string "################"
	chVazio:		.string "-"
	chCheio:		.string "+"

.section .text

.globl iniciaAlocador, finalizaAlocador, alocaMem, liberaMem, imprimeMapa, olhos
# olhos soh para debugar com testesss


iniciaAlocador:
	# ||<= %brk
	# | L | 4080 |  ---- 4080 ---- |<= %brk (um total de 4096)
	# ^0(olhos)
	#            ^16(olhos)

	# chama printf antes pra alocar o buffer e nn atrapalhar a brk
	movq $strinit, %rdi
	call printf

	# pergunta pro SO endereco de brk e salva 	
	movq $12, %rax							# comando: cade brk?
	movq $0, %rdi							# me diga pfr
	syscall 								# brk vem no %rax
	movq %rax, inicio_heap					# inicio_heap = endereco de brk
	movq %rax, olhos						# inicia olhos para primeiro nó

	# aumenta heap em Block_size bytes + IG
	movq inicio_heap, %rbx					# rbx = brk
	movq Block_size, %r10					# r10 = Block_size
	addq $16, %r10							# r10 += sizeof(IG)
	addq %r10, %rbx 						# rbx = inicio_heap + Block_size + 16

	# empurra brk pra baixo => brk = brk + Block_size
	movq $12, %rax
	movq %rbx, %rdi
	syscall
	movq %rax, final_heap

	# registra INFORMACOES GERENCIAIS (IG)
	# inicio_heap = Livre
	# 8(inicio_heap) = tamanho Livre
	# tam total disp = tam bloco - tam IG
	movq inicio_heap, %rax					# rax = inicio_heap
	movq LIVRE, %rbx						# rbx = LIVRE
	movq %rbx, 0(%rax)						# inicio_heap[0] = bloco seguinte esta LIVRE
	movq Block_size, %rbx					# rbx = 4096
	# subq $16, %rbx							# tamanho disponivel eh 4096 - tamanho IG
	movq %rbx, 8(%rax)						# inicio_heap[1] = tam disponivel (4080)

	ret


# recebe em %rdi o tamanho a ser alocado
# devolve em %rax o endereco do bloco alocado
# Se foi alocado, o olho ja aponta para o proximo nodo livre
# <================= PSEUDO CODIGO =================>
# loop:
# 	if(cabe):							# LIVRE && tamAloc +16 < tamNodo 
# 		aloca tamAloc					# seta IG
# 		circular = 0					# reinicia flag da volta
# 		return endereco					# return 16(olhos) 1o byte acessivel
# 	if(nao_cabe):						# else
# 		if(proximo):					# 8(olhos) + tamAloc + 16 < final_heap
# 			proximo						# olhos = olhos + 8(olhos) + 8     // nn tenho ctz 
#			jmp loop
# 		if(nao_proximo):				# else
# 			if(circular == 0):			# se bateu na heap e nao deu a volta, da a volta
# 				circular = 1
# 				olhos = inicio_heap
# 				jmp loop
# 			if(circular == 1):			# se bateu na heap e deu volta
# 				aumenta heap			# aumenta heap
# 				seta IG 				
# 				jmp loop				# procura dnv, se nn couber ainda, cai aki dnv
alocaMem:
		movq %rdi, %r12 


	loopmemm:
		call achaMaior
		movq %rax, %r13

		movq 8(%r13), %rax

		subq $16, %rax					# cabe um aloc e o proximo IG?
		cmpq %rax, %r12					# %rbx <= %rax
		jl devolveAloc					# if(rdi < tamMaior - 16) aloca

		jmp loopmemm
		
		devolveAloc:
			# aloca tamAloc	
			movq OCUPA, %rax				# seta IG
			movq %rax, 0(%r13)				# bloco OCUPADO

			movq 8(%r13), %r11 				# r11 = tamanho antigo do bloco
			movq %r12, 8(%r13)				# salva novo tamanho do bloco

			# cria proximo IG				# r10 -> vai ser o proximo 'IG'
			movq %r13, %r10				# r10 = endereco de olhos
			addq $16, %r10					# r10 += 16
			addq %r12, %r10					# r10 = olhos + novo tamanho + 16

			movq LIVRE, %rbx				# proximo IG = (ender de olhos) + tam antigo bloco + 16 [tam IG[1] + prox byte dpois do tamAloc]
			movq %rbx, 0(%r10)				# proximo IG[0] -> LIVRE
			
			movq %r11, %rbx					# rbx = tamanho antigo bloco
			subq 8(%r13), %rbx				# rbx -= tamanho novo bloco
			subq $16, %rbx					# rbx -= 16 
			movq %rbx, 8(%r10)				# proximo IG[1] = tam_bloco_old - tam_bloco_novo - 16 (tamanho IG)
			
			# return endereco
			movq %r13, %rax				# rax = endereco olhos
			addq $16, %rax					# rax = endereco olhos + 16 (endereco 1o byte usavel)

			ret								# retorna endereco do bloco usavel 
			jmp fusao


finalMaior:
	movq %r15, %rax
	ret

achaMaior:
		movq inicio_heap, %r9			# r9 VAI ITERAR NA HEAP
		movq inicio_heap, %r15			# GUARDA O MAXIMO

		
	loopMaior:
		movq final_heap, %rax			# se iterador >= heap return
		cmpq %rax, %r9
		jge finalMaior

		movq 0(%r9), %rax				# livre ou ocupado do iterador
		movq 8(%r9), %rbx				# tamanho do iterador

		# if ( cabe )
		movq LIVRE, %rcx				# se bloco ocupado, vai pro proximo
		cmpq %rax, %rcx					# 0(olhos)-> IG[0] != LIVRE		
		jne proximomaior

		# o bloco eh livre
		movq 8(%r9), %rax
		movq 8(%r15), %rbx 
		cmpq %rbx, %rax
		jle proximomaior				# if( tamIterador > tamMaximo) maximo = iterador 

		# se tam iterador > maior
		movq %r9, %r15
		jmp loopMaior

	# if(!cabe)	
	proximomaior: 
		# if(proximo):					# 8(olhos) + tamAloc + 16 < final_heap
		# 	proximo						# olhos = olhos + 8(olhos) + 16     
		# 	jmp loop

		movq 8(%r9), %rax				# endereco do proximo no em rax
		addq %r9, %rax					# rax = olhos + 8(olhos)
		addq $16, %rax					# rax = olhos + tam_bloco + 16

		movq %rax, %r9				# olhos = proximo
		jmp loopMaior					# procura denovo

# se nao cabe nodo, nao tem proximo e ja deu a volta
# aloca mais espaco na heap
	deu_volta:
		movq Block_size, %rax		# tamanho a aumentar a heap
		movq final_heap, %rbx 
		movq final_heap, %r14		# final heap antigo

		addq %rax, %rbx				# rbx = final_heap += 4096
		addq $16, %rbx
		movq $12, %rax				# SO favor aumentar
		movq %rbx, %rdi				# a heap para %rbx
		syscall		
		movq %rax, final_heap		# atualiza valor final_heap	


		# cria proximo IG SEM MEXER NOS OLHOS  r10 -> vai ser o proximo 'olho'
		movq LIVRE, %rbx				# prox IG = (ender de olhos) + tam antigo bloco + 16 [tam IG[1] + prox byte dpois do tamAloc]
		movq %rbx, 0(%r14)				# proximo IG[0] -> LIVRE // antes dava ruim aki
		
		movq Block_size, %rbx			# rbx = tamanho  bloco
		movq %rbx, 8(%r14)				# 8(proximo) =  tam_bloco_novo 

		# caso bloco livre atras, junta
		# movq LIVRE, %rax
		# movq olhos, %rbx
		# movq 0(%rbx), %rcx
		# cmpq %rax, %rcx
		# jne alocaMem

		# # junta livre atras com livre agora
		# movq Block_size, %rax 
		# movq 8(%rbx), %rcx
		# addq $16, %rcx 
		# addq %rax, %rcx
		# movq %rcx, 8(%rbx)

		jmp loopmemm

# pseudo codigo aki pfr
# %rcx = inicio heap
# %rbx = inicio heap
# %rbx += IG[1]
# %rbx += 16
# while(%rbx < brk)
# {
#     if((%rcx) == LIVRE)
#	  {
#		 if((%rbx) == LIVRE)
#		 {
#			 8(%rcx) += 8(%rbx)
#			 8(%rcx) += 16
#			 %rbx += 8(%rbx)
#			 %rbx += 16
#		 }
#		 else
#		 {
#			 %rcx += 8(%rbx)
#			 %rcx += 16
#			 %rbx = %rcx
#			 %rbx += 8(%rbx)
#			 %rbx += 16
#		 }
# 	  }
#	  else
#	  {
#		 %rcx += 8(%rbx)
#		 %rcx += 16
#		 %rbx = %rcx
#		 %rbx += 8(%rbx)
#		 %rbx += 16
#	  }
# } 
# rbx -> r13  esses registradores sao preservados
# rcx -> r12
ocupado:
	movq LIVRE, %r10
	movq OCUPA, %r11

	movq 8(%r12), %rax			# move base 1 pra frente (rcx)
	addq %rax, %r12				# mudando a cabeça de verificação
	addq $16, %r12			

	movq 8(%r13), %rax 			# move (rbx) 1 pra frente 
	addq %rax, %r13				# %rbx += 16 -> (IG anterior)
	addq $16, %r13	

	cmpq %r14, %r13				# se esta no fim da heap
	jge fim						# sai
	
	cmpq %r11, 0(%r12) 			# se base estiver ocupado
	je ocupado					# muda a cabeça de verificação

	cmpq %r10, 0(%r12) 			# se base estiver livre
	je varredura				# inicia verificação a partir dele

	jmp fim

seg_ocupado:
	movq LIVRE, %r10
	movq OCUPA, %r11

	movq %r13, %r12				# mudando a cabeça de verificação
								# para a posição do segundo olho

	movq 8(%r12), %rax			# move base 1 pra frente (rcx)
	addq $16, %rax
	addq %rax, %r12				# mudando a cabeça de verificação			

	movq 8(%r13), %rax 			# move (rbx) 1 pra frente 
	addq $16, %rax	
	addq %rax, %r13				# %rbx += 16 -> (IG anterior)

	movq 8(%r13), %rax 			# move (rbx) 2 pra frente 
	addq $16, %rax	
	addq %rax, %r13				# %rbx += 16 -> (IG anterior)
	
	cmpq %r14, %r13	 			# se esta no fim da heap
	jge fim						# sai
	
	cmpq %r11, 0(%r12) 			# se base estiver ocupado
	je ocupado					# muda a cabeça de verificação

	cmpq %r10, 0(%r12) 			# se base estiver livre
	je varredura				# inicia verificação a partir dele

	jmp fim

soma:
	movq LIVRE, %r10
	movq OCUPA, %r11

	movq 8(%r13), %rax			# rcx[1] += rbx[1] + 16
	addq $16, %rax				# %rcx += 16 -> (IG)
	addq %rax, 8(%r12)			# IG[1] += tamanho do bloco que esta livre a frente

	movq 8(%r13), %rax 			# move (rbx) 1 pra frente 
	addq $16, %rax
	addq %rax, %r13				# %rbx += 16 -> (IG anterior)
		

	cmpq %r14, %r13				# se esta no fim da heap
	jge fim						# sai
	
	cmpq %r11, 0(%r13) 			# se base estiver ocupado
	je seg_ocupado					# muda a cabeça de verificação

	cmpq %r10, 0(%r13) 			# se base estiver livre
	je varredura				# inicia verificação a partir dele

	ret
	jmp fim 

varredura:
	movq LIVRE, %r10
	movq OCUPA, %r11
	
	cmpq %r10, 0(%r13) 			# se o proximo bloco estiver livre
	je soma						# soma ao tamanho do bloco anterior

	cmpq %r11, 0(%r13) 			# se o bloco estiver ocupado
	je seg_ocupado

	ret
	jmp fim

fusao:
	movq inicio_heap, %r12 		# inicio da heap vai pra %rax
	movq inicio_heap, %r13

	movq final_heap, %rax		# final da heap 
	movq %rax, %r14
	
	addq 8(%r13), %rcx 			# %rbx += IG[1] -> prox bloco
	addq $16, %rcx				# %rbx += 16 -> (IG anterior)
	addq %rcx, %r13

	cmpq %r14, %r12				# se esta no fim da heap
	jge fim						# sai

	cmpq %r14, %r13				# se esta no fim da heap
	jge fim						# sai

	movq OCUPA, %r10
	cmpq %r10, 0(%r12) 			# se o bloco estiver ocupado
	je ocupado					# va para o prox bloco

	movq LIVRE, %r10
	cmpq %r10, 0(%r12) 			# se o primeiro bloco estiver livre
	je varredura				# inicia a varredura

	ret
	jmp fim 

liberaMem:
	movq LIVRE, %rax			# recebe endereco 16 bytes a frente de IG
	movq %rax, -16(%rdi)		# IG[0] = LIVRE
	
	jmp fusao

	ret
# liberaMem:
# 	movq LIVRE, %rax			# recebe endereco 16 bytes a frente de IG
# 	movq %rax, -16(%rdi)		# IG[0] = LIVRE
	
# 	# empurra olho pra frente
# 	movq final_heap, %rbx		# se bloco livre atras desse olho, nao perde ponteiro
# 	movq olhos, %rax
# 	addq $16, %rax
# 	addq -8(%rdi), %rax
# 	cmpq %rbx, %rax 			# se prox olhos < final_heap
# 	jge naoproxliberamem

# 	movq %rax, olhos

# naoproxliberamem:
# 	jmp fusao

# 	ret

finalizaAlocador:
	# diminui brk para o endereco inicial
	movq $12, %rax 							# resize brk
	movq inicio_heap, %rdi					# nova altura
	syscall 
	
	ret

fim:
	movq %r15, %rax

	ret


# //////// pseudo codigo imprimeMapa bonito ///////////
#   void *final, *olhos;
# 	long *olho;
# 	char state;
# 	final = getFim();
# 	olhos = getInit();

# 	while(olhos  + 16 < final)
# 	{
# 		olho = (long *)olhos;
# 		state = (olho[0] == 0) ? 'L' : 'X';
# 		// printf("( %c | %li )..", state, olho[1]);

# 		olhos += olho[1] + 16;
# 	}
# 	// printf("final heap\n");
PrintFinal:
		movq $strfinal, %rdi
		call printf
		ret

printNODO:
	movq 0(%rdi), %r12
	movq 8(%rdi), %r14

	movq $strIG, %rdi
	call printf

	cmpq %r12, LIVRE
	je setaLivre
	jne setaOcupado

	setaLivre:
		movq $chVazio, %r12
		jmp loooop
	setaOcupado:
		movq $chCheio, %r12
		jmp loooop

	loooop:
		cmpq $0, %r14
		je fimloooop

		movq %r12, %rdi
		call printf

		subq $1, %r14
		jmp loooop


	fimloooop:
	ret

imprimeMapa:
	movq inicio_heap, %r15
	movq final_heap, %r13
	subq $16, %r13

	loopMapa:

		#print("nodo", estado, tamanho);
		movq %r15, %rdi
		call printNODO

		# proximo nodo
		movq 8(%r15), %rax				# tamanho do no atual
		addq %rax, %r15					# prox = atual + 8(olhos)
		addq $16, %r15					# prox = atual + tam_bloco + 16

		cmpq %r13, %r15					# if olho + 16 < final_heap, imprime proximo 
		jl loopMapa

		call PrintFinal
		ret


# PRINT MAPA LEGIVEL PARA DEBUGAR ----> 
PrintFinalBUNITO:
		movq $strfinal, %rdi
		call printf
		ret

printNODOBUNITO:
	movq 0(%rdi), %rsi
	movq 8(%rdi), %rdx
	movq $strnodo, %rdi
	call printf
	ret

imprimeMapaasdf:
	movq inicio_heap, %r15
	movq final_heap, %r13
	subq $16, %r13

	loopMapaBUNITO:

		#print("nodo", estado, tamanho);
		movq %r15, %rdi
		call printNODOBUNITO

		# proximo nodo
		movq 8(%r15), %rax				# tamanho do no atual
		addq %rax, %r15					# prox = atual + 8(olhos)
		addq $16, %r15					# prox = atual + tam_bloco + 16

		cmpq %r13, %r15					# if olho + 16 < final_heap, imprime proximo 
		jl loopMapaBUNITO

		call PrintFinalBUNITO
		ret
