.section .data
	inicio_heap: 	.quad 0			# valor inicial da heap, antes do iniciaAlocador
	final_heap:		.quad 0			# valor final da heap, em qualquer dado momento
	block_size:		.quad 4096		# tamanho dos blocos alocados, quando heap cheia
	LIVRE: 			.quad 0			# bool que representa um bloco LIVRE
	OCUPA:			.quad 1			# bool que representa um bloco OCUPADO
	
	olhos:			.quad 0			# variavel que contem o ultimo nó analizado
	circular:		.quad 0			# se olhos ja circularam na heap, $1, else $0, usamos pra
									# decidir se é preciso aumentar a heap ou nao

	strinit:		.string " "
	strnodo:		.string "( %i | %i ).."
	strfinal:		.string "final Heap\n"

.section .text

.globl iniciaAlocador, finalizaAlocador, alocaMem, liberaMem, getBrk, getInit, getFim, imprimeMapa
# nao_cabe, nao_proximo, deu_volta,


# retorna o endereco de brk em rax 
getBrk:
	movq $12, %rax
	movq $0, %rdi
	syscall # brk comes on %rax, 
	ret		# returns %rax

getInit:
	movq inicio_heap, %rax;
	ret
getFim:
	movq final_heap, %rax
	ret

iniciaAlocador:
	# ||<= %brk
	# | L | 4096 |  ---- 4096 ---- |<= %brk

	# chama printf antes pra alocar o buffer e nn atrapalhar a brk
	movq $strinit, %rdi
	call printf

	# pergunta pro SO endereco de brk e salva 	
	movq $12, %rax							# comando: cade brk?
	movq $0, %rdi							# me diga pfr
	syscall 								# brk vem no %rax
	movq %rax, inicio_heap					# inicio_heap = endereco de brk

	# aumenta heap em block_size bytes + IG
	movq inicio_heap, %rbx					# rbx = brk
	movq block_size, %r10					# r10 = block_size
	addq $16, %r10							# r10 += sizeof(IG)
	addq %r10, %rbx 						# rbx = inicio_heap + block_size + 16

	# empurra brk pra baixo => brk = brk + block_size
	movq $12, %rax
	movq %rbx, %rdi
	syscall
	movq %rax, final_heap

	# registra INFORMACOES GERENCIAIS (IG)
	# inicio_heap = Livre/Ocupado
	# 8(inicio_heap) = tamanho Livre/Ocupado  
	# tam total disp = tam bloco - tam IG
	movq inicio_heap, %rax					# rax = inicio_heap
	movq LIVRE, %rbx						# rbx = LIVRE
	movq %rbx, 0(%rax)						# inicio_heap[0] = bloco seguinte esta LIVRE
	movq block_size, %rbx					# rbx = 4096
	subq $16, %rbx							# tamanho disponivel eh 4096 - tamanho IG
	movq %rbx, 8(%rax)						# inicio_heap[1] = tam disponivel (4080)

	movq inicio_heap, %rax					# inicia olhos para primeiro nó
	movq %rax, olhos

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
		movq olhos, %r9					# r9 = olhos, ao longo do alocaMem inteiro
		movq 0(%r9), %rax				# rax = status do nodo
		movq 8(%r9), %rbx				# rbx = tamanho nodo

		# if ( cabe )
		cmpq %rax, LIVRE				# 0(olhos)-> IG[0] != LIVRE		
		jne nao_cabe

		movq %rdi, %rax					# rax = tamAloc
		# addq $16, %rax				# tamanho ja eh guardado em IG corrigido
		cmpq %rax, %rbx					# %rbx <= %rax
		jl nao_cabe					# jump if tamanho nodo < tamAloc + 16

		# print auxiliar
		# movq $1, %rax # 1 CABE

		# circular = 0					# reinicia flag da volta
		movq $0, circular
		
		# aloca tamAloc					# seta IG
		movq OCUPA, %rax
		movq %rax, 0(%r9)				# bloco OCUPADO

		movq 8(%r9), %r11 				# r11 = tamanho antigo do bloco
		movq %rdi, 8(%r9)				# salva novo tamanho do bloco

		# cria proximo IG				# r10 -> vai ser o proximo 'olho'
		movq olhos, %r10				# r10 = endereco de olhos
		addq $16, %r10					# r10 += 16
		addq %rdi, %r10					# r10 += novo tamanho

		movq LIVRE, %rbx				# prox IG = (ender de olhos) + tam antigo bloco + 16 [tam IG[1] + prox byte dpois do tamAloc]
		movq %rbx, 0(%r10)				# proximo IG[0] -> LIVRE
		
		movq %r11, %rbx					# rbx = tamanho antigo bloco
		subq 8(%r9), %rbx				# rbx -= tamanho novo bloco
		subq $16, %rbx					# rbx -= 16
		movq %rbx, 8(%r10)				# proximo IG[1] = tam_bloco_old - tam_bloco_novo - 16 (tamanho IG)
		
		# return endereco
		movq olhos, %rax				# rax = endereco olhos
		addq $16, %rax					# rax = endereco olhos + 16 (endereco 1o byte usavel)

		# setar proximo olho
		movq %r10, olhos

		ret								# retorna endereco do bloco usavel 

	# if(!cabe)	
	nao_cabe: 
		# print auxiliar
		# movq $0, %rax # 0 NAO CABE
		# ret
		# if(proximo):					# 8(olhos) + tamAloc + 16 < final_heap
		# 	proximo						# olhos = olhos + 8(olhos) + 16     
		# 	jmp loop

		movq olhos, %r9
		movq 8(%r9), %rax				# endereco do proximo no em rax
		addq %r9, %rax					# rax = olhos + 8(olhos)
		addq $16, %rax					# rax = olhos + tam_bloco + 16

		cmpq final_heap, %rax			# se proximo >= heap, rax >= final_heap
		jge nao_proximo

		movq %rax, olhos				# olhos = proximo
		jmp alocaMem					# procura denovo

	nao_proximo:
		# if(circular == 0):			# se bateu na heap e nao deu a volta, da a volta
		# 	circular = 1
		# 	olhos = inicio_heap
		# 	jmp loop

		movq circular, %rax
		cmpq $1, %rax
		je deu_volta				# if(circular == 1) jump deu_volta, se nao, continua

		movq inicio_heap, %rax		# olhos = inicio_heap
		movq %rax, olhos

		movq $1, circular			# deu a volta

		jmp alocaMem				# comeca a procurar denovo

		# if(circular == 1):		# se bateu na heap e deu volta
		# 	aumenta heap			# aumenta heap
		# 	seta IG 				
		# 	jmp loop				# procura dnv, se nn couber ainda, cai aki dnv
# se nao cabe nodo, nao tem proximo e ja deu a volta
# aloca mais espaco na heap
	deu_volta:
		movq block_size, %rax		# tamanho a aumentar a heap
		movq final_heap, %rbx		# rax novo final_heap 

		addq %rax, %rbx				# rbx = final_heap += 4096

		movq $12, %rax				# SO favor aumentar
		movq %rbx, %rdi				# a heap para %rbx
		syscall		
		movq final_heap, %r11		# final_heap antigo	
		movq %rax, final_heap		# atualiza valor final_heap			

		# cria proximo IG SEM MEXER NOS OLHOS  r10 -> vai ser o proximo 'olho'
		movq olhos, %r10				# r10 = endereco de olhos
		addq $16, %r10					# r10 += 16
		movq 16(%r10), %rbx			# rbx = tamanho do bloco
		addq %rbx, %r10					# proximo olhos = olhos + tam bloco + 16(tam IG)

		movq LIVRE, %rbx				# prox IG = (ender de olhos) + tam antigo bloco + 16 [tam IG[1] + prox byte dpois do tamAloc]
		movq %rbx, 0(%r10)				# proximo IG[0] -> LIVRE
		
		movq block_size, %rbx			# rbx = tamanho antigo bloco
		subq $16, %rbx					# rbx -= tamanho novo bloco
		movq %rbx, 8(%r10)				# proximo IG[1] = tam_bloco_old - tam_bloco_novo - 16 (tamanho IG)

		# caso bloco livre atras, chama fusao
		# call fusao

		jmp alocaMem


##### o fusao q eu tentei fazer kkkkkkkkkk :(
# # for(a = inicio_heap; a + 16 < final_heap; prox(a))
# # {
# # 	if(a[1] == livre)
# # 	{
# # 		for(b = prox(a); b + 16 < final_heap; prox(b)
# # 		{
# # 			if(b[1] != livre)
# # 			{
# # 				a = b;
# # 				break;
# # 			}
# # 			a[1] += b[1];
# # 		}
# # 	}
# # }
# fusao:
# 	movq inicio_heap, %r10
# 	movq %r10, %r11						# b = a
	
# 	# itera sobre olho1 (%r10)
# 	loop1fusao:
# 		#se livre vai pro loop 2
# 		movq LIVRE, %rax
# 		movq 0(%r10), %rbx
# 		cmpq %rax, %rbx
# 		je loop2fusao

# 		# senao
# 		# proximo(a)
# 		movq 8(%r10), %rax				# endereco do proximo no em rax
# 		addq %rax, %r10					
# 		addq $16, %r10	
# 		movq %r10, %r11					# b = a

# 		movq final_heap, %rbx
# 		subq $16, %rbx
# 		cmpq %rbx, %r10					# se a + 16 < heap
# 		jl loop1fusao

# 		ret								# caso contrario, termina fusao

# 	# itera sobre olho2 (%r11)
# 	loop2fusao:
# 		#se b bateu na heap, volta loop 1
# 		movq final_heap, %rbx
# 		subq $16, %rbx
# 		cmpq %rbx, %r11				
# 		jl loop1fusao

# 		# proximo(b)
# 		movq 8(%r11), %rax				
# 		addq %rax, %r11
# 		addq $16, %r11

# 		# se b OCUPADO
# 		movq OCUPA, %rax
# 		movq 0(%r11), %rbx
# 		cmpq %rax, %rbx
# 		je loop1fusao

# 		# se b livre
# 		#a[1] += b[1]
# 		movq 8(%r11), %rax
# 		movq 8(%r10), %rbx
# 		addq %rbx, %rax

# 		movq %rax, 8(%r10)
# 		jmp loop2fusao

ocupado:
	movq LIVRE, %r10
	movq OCUPA, %r11
	
	addq 8(%rbx), %rcx			# mudando a cabeça de verificação
	addq $16, %rcx				#
	movq %rcx, %rbx				# atualizando registradores aux
	addq 8(%rbx), %rbx 			# %rbx += IG[1] -> prox bloco
	addq $16, %rbx				# %rbx += 16 -> (IG anterior)

	movq $12, %rax				#
	movq $0, %rdi				#
	syscall						# verifica se esta no fim da heap alocada
	cmpq %rax, %rbx				# 
	jge fim						#
	
	cmpq %r10, 0(%rcx) 			# se o bloco estiver livre
	je varredura				# inicia verificação a partir dele
	
	cmpq %r11, 0(%rcx) 			# se o bloco estiver ocupado
	je ocupado					# muda a cabeça de verificação

soma:
	movq 8(%rbx), %r12
	addq %r12, 8(%rcx)			# IG[1] += tamanho do bloco que esta livre a frente
	addq $16, 8(%rcx)			# %rcx += 16 -> (IG)
	ret

varredura:
	movq LIVRE, %r10
	movq OCUPA, %r11
	
	cmpq %r10, 0(%rbx) 			# se o proximo bloco estiver livre
	je soma						# soma ao tamanho do bloco anterior
	
	cmpq %r11, 0(%rbx) 			# se o bloco estiver ocupado
	je ocupado

	addq 8(%rbx), %rbx 			# proximo bloco de memoria
	addq $16, %rbx

	movq $12, %rax				#
	movq $0, %rdi				#
	syscall						# verifica se esta no fim da heap alocada
	cmpq %rax, %rbx				# 
	jge fim						# ACHO QUE AQUI ESTA O ERRO
								# PRECISO DAR UM RETURN linha 250 tbm
	
	cmpq %r10, 0(%rbx) 			# se livre
	je varredura

	cmpq %r11, 0(%rbx) 			# se o bloco estiver ocupado
	je ocupado

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
fusao:
	movq inicio_heap, %rcx 		# inicio da heap vai pra %rax
	movq inicio_heap, %rbx
	
	addq 8(%rbx), %rbx 			# %rbx += IG[1] -> prox bloco
	addq $16, %rbx				# %rbx += 16 -> (IG anterior)

	movq LIVRE, %r10
	cmpq %r10, 0(%rcx) 			# se o primeiro bloco estiver livre
	je varredura				# inicia a varredura

	movq OCUPA, %r10
	cmpq %r10, 0(%rcx) 			# se o bloco estiver ocupado
	je ocupado					# va para o prox bloco
	ret

liberaMem:
	movq LIVRE, %rax			# recebe endereco 16 bytes a frente de IG
	movq %rax, -16(%rdi)		# IG[0] = LIVRE
	
	call fusao					

	ret


finalizaAlocador:
	# diminui brk para o endereco inicial
	movq $12, %rax 							# resize brk
	movq inicio_heap, %rdi					# nova altura
	syscall 
	
	ret

fim:
	ret


imprimeMapa:
	movq inicio_heap, %r10

	loopMapa:
		#print(nodo)
		movq 0(%r10), %rsi
		movq 8(%r10), %rdx
		movq $strnodo, %rdi
		call printf

		# proximo nodo
		movq 8(%r10), %rax				# endereco do proximo no em rax
		addq %rax, %r10					# nodo = olhos + 8(olhos)
		addq $16, %r10					# nodo = olhos + tam_bloco + 16

		movq final_heap, %rax
		subq $16, %rax
		cmpq %rax, %r10					# if olho + 16 < final_heap, imprime proximo 
		jl loopMapa

		movq $strfinal, %rdi
		call printf

		ret