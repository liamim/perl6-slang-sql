use QAST:from<NQP>;

sub perform(Str $statement, @args?, $cb?) is export {
  $*DB.do($statement, @args), return if !defined $cb;
  my $*STATEMENT = $statement;
  my $sth = $*DB.prepare($statement);
  $sth.execute(@args);
  while (my $ROW = $sth.fetchrow_hashref) {
    try {
      $cb($ROW);
    };
  }
  $sth.finish;
}

sub EXPORT(|) {
  role SQL::Grammar {
    rule statement_control:sym<exec> {
      <sym>  
      <sql>
      [
        | ''
        | ';'
          'with'
          '('
            <arglist>
          ')'
      ]
      [ 
        | ''
        | 
          'do'
          <pblock>
      ]
    }
    token sql {
      [ \'.*?\' || \".*?\" || .]*? )> <before ';'>
    }
  }
  role SQL::Actions {
    sub lk(Mu \h, \k) {
      nqp::atkey(nqp::findmethod(h, 'hash')(h), k)
    }
    method statement_control:sym<exec>(Mu $/ is rw) {
      my $sql   := lk($/, 'sql');
      my $args  := lk($/, 'arglist');
      my $cb    := lk($/, 'pblock');
      if $args.WHAT !~~ Mu {
        $args := $args.ast;
        $args.name('&infix:<,>');
      } else {
        $args := QAST::Op.new(
                   :op<call>,
                   :name('&infix:<,>'),
                 );
      }
      if Mu ~~ $cb.WHAT {
        $cb := QAST::WVal.new(:value<PBlock>);
      } else {
        $cb := $cb.made;
      }
      my $block := QAST::Op.new(
                     :op<call>, 
                     :name<&perform>, 
                     QAST::SVal.new(:value($sql.Str)),
                     $args, 
                     $cb
                   );
      $/.'!make'($block);
    }
  }
  nqp::bindkey(%*LANG, 'MAIN', %*LANG<MAIN>.HOW.mixin(%*LANG<MAIN>, SQL::Grammar));
  nqp::bindkey(%*LANG, 'MAIN-actions', %*LANG<MAIN-actions>.HOW.mixin(%*LANG<MAIN-actions>, SQL::Actions));
  {}
}

