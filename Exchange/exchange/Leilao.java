package exchange;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.TreeSet;
import java.util.stream.Collectors;

public class Leilao extends Emprestimo{
    private boolean sucesso;
    
    public Leilao(int id, String empresa, long montante, float taxa, LocalDateTime fim){
        super(id, empresa, montante, taxa, fim);
    }

    private boolean verificaUltrapassados()
        throws ExcecaoUltrapassado{
        long montanteAmealhado = 0;
        ArrayList<Proposta> clientes = new ArrayList<>();
        for(Proposta p: propostas.descendingSet()){
            if(montanteAmealhado > montante){
                clientes.add(p);
            }
            else{
                montanteAmealhado += p.montante;
            }
        }
        
        if(clientes.size() != 0){
            propostas.removeAll(clientes);
            throw new ExcecaoUltrapassado(propostas.first(),clientes,"A sua proposta foi ultrapassada!");
        }

        return true;
    }

    private long montanteAmealhado(){
        return propostas.stream()
                .mapToLong(a -> a.montante)
                .sum();
    }   

    private boolean adicionaProposta(Proposta p)
        throws ExcecaoUltrapassado{
        //metodo que verifica se a proposta vai ficar colocada, em caso afirmativo adiciona a mesma
        //retorna a proposta que foi removida, ou null no caso de nenhuma ter sido
        //caso a proposta nao seja adicionada retorna-a
        if(this.montanteAmealhado() < montante){
            propostas.add(p);
            return verificaUltrapassados();
        }
        else{
            if(p.compareTo(propostas.first()) < 0){
                return false;
            }
            propostas.add(p);
            return verificaUltrapassados();
        }
    }

    public boolean licita(String cliente, long montante, float taxa)
        throws ExcecaoUltrapassado{
        //faz uma licitacao ao leilao
        //caso seja adicionado ao leilao e outro seja removida tem de avisar o que foi removido
        if(taxa > this.taxa){
            return false;
        }

        Proposta p = new Proposta(ultimaProposta++,cliente, montante, taxa);
        return adicionaProposta(p);
    }

    public boolean termina(){
        //termina o respetivo leilao
        terminado = true;
        long montanteAmealhado = propostas.stream()
                                    .mapToLong(p -> p.montante)    
                                    .sum();
        sucesso = (montanteAmealhado >= montante ? true : false);
        if(sucesso){
            long diferenca = montanteAmealhado - montante;
            propostas.first().montante -= diferenca;
        }
        return sucesso;
    }

    public boolean equals(Object o){
        if(o==null) return false;

        if(!(o instanceof Leilao)) return false;

        Leilao e = (Leilao)o;

        return ((e.id == this.id) && (e.empresa.equals(this.empresa)));
    }
}