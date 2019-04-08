package Mojo::Feed::Atom;
use Mojo::Base -base;

my %atom = (
  title => ['title'],
  subtitle => ['subtitle', 'tagline'],
  link => ['link:not([rel])', 'link[rel=alternate]'],
  id => ['id'],
  updated => ['updated'],
  published   => ['published'],
  author   => ['author'],
  generator    => ['generator'],
  rights    => ['rights'],
  logo => ['logo'],
  icon => ['icon'],
  contributor => ['contributor'],
  category => ['category'],
);

foreach my $k (keys %atom) {
  has $k => sub {
    my $self = shift;
    for my $atom (@{$atom{$k}}) {
      if (my $p = $self->dom->at("feed > $atom")) {
        if ($k eq 'author' && $p->at('name')) {
          return $p->at('name')->text;
        }
        my $text = $p->text || $p->content || $p->attr('href');
        if ($k eq 'published') {
          return str2time($text);
        }
        return $text;
      }
    }
    return;
  };
}

has entries => sub {
  my $self = shift;
  $self->dom->find('entry')
    ->map(sub { Mojo::Feed::Item::Atom->new(dom => $_, feed => $self) });
};




1;
