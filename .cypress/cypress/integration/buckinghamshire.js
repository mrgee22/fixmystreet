describe('buckinghamshire cobrand', function() {

  beforeEach(function() {
    cy.server();
    cy.route('**mapserver/bucks*Whole_Street*', 'fixture:roads.xml').as('roads-layer');
    cy.route('**mapserver/bucks*WinterRoutes*', 'fixture:roads.xml').as('winter-routes');
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.route('/around\?ajax*').as('update-results');
    cy.route('/around/nearby*').as('around-ajax');
    cy.visit('http://buckinghamshire.localhost:3001/');
    cy.contains('Buckinghamshire');
    cy.get('[name=pc]').type('SL9 0NX');
    cy.get('[name=pc]').parents('form').submit();
    cy.wait('@update-results');
  });

  it('sets the site_code correctly', function() {
    cy.get('#map_box').click(290, 307);
    cy.wait('@report-ajax');
    cy.pickCategory('Roads & Pavements');
    cy.wait('@roads-layer');
    cy.nextPageReporting();
    cy.pickSubcategory('Roads & Pavements', 'Parks');
    cy.get('[name=site_code]').should('have.value', '7300268');
    cy.nextPageReporting();
    cy.contains('Photo').should('be.visible');
  });

  it('uses the label "Full name" for the name field', function() {
    cy.get('#map_box').click(290, 307);
    cy.wait('@report-ajax');
    cy.pickCategory('Flytipping');
    cy.wait('@around-ajax');

    cy.nextPageReporting();
    cy.get('#form_road-placement').select('off-road');
    cy.nextPageReporting();
    cy.nextPageReporting(); // No photo
    cy.get('[name=title]').type('Title');
    cy.get('[name=detail]').type('Detail');
    cy.nextPageReporting();
    cy.get('label[for=form_name]').should('contain', 'Full name');
  });

  it('shows gritting message', function() {
    cy.get('#map_box').click(290, 307);
    cy.wait('@report-ajax');
    cy.pickCategory('Roads & Pavements');
    cy.wait('@roads-layer');
    cy.nextPageReporting();
    cy.pickSubcategory('Roads & Pavements', 'Snow and ice problem/winter salting');
    cy.wait('@winter-routes');
    cy.nextPageReporting();
    cy.contains('The road you have selected is on a regular gritting route').should('be.visible');
  });

  describe("Parish grass cutting category speed limit question", function() {
    var speedGreaterThan30 = '#form_speed_limit_greater_than_30';

    beforeEach(function() {
      cy.get('#map_box').click(290, 307);
      cy.wait('@report-ajax');
      cy.pickCategory('Grass, hedges and weeds');
      cy.nextPageReporting();
      cy.pickSubcategory('Grass hedges and weeds', 'Grass cutting');
      cy.wait('@around-ajax');
      cy.nextPageReporting();
    });

    it('displays the parish name if answer is "no"', function() {
      cy.get(speedGreaterThan30).select('no');
      cy.nextPageReporting();
      cy.nextPageReporting();
      cy.contains('sent to Adstock Parish Council and also published online').should('be.visible');
    });

    it('displays the council name if answer is "yes"', function() {
      cy.get(speedGreaterThan30).select('yes');
      cy.nextPageReporting();
      cy.nextPageReporting();
      cy.contains('sent to Buckinghamshire Council and also published online').should('be.visible');
    });

    it('displays the council name if answer is "dont_know"', function() {
      cy.get(speedGreaterThan30).select('dont_know');
      cy.nextPageReporting();
      cy.nextPageReporting();
      cy.contains('sent to Buckinghamshire Council and also published online').should('be.visible');
    });
  });
});

describe('buckinghamshire roads handling', function() {
  beforeEach(function() {
    cy.server();
    cy.route('**mapserver/bucks*Whole_Street*', 'fixture:roads.xml').as('roads-layer');
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.viewport(480, 800);
    cy.visit('http://buckinghamshire.localhost:3001/');
    cy.get('[name=pc]').type('SL9 0NX');
    cy.get('[name=pc]').parents('form').submit();

    cy.get('#map_box').click(290, 307);
    cy.wait('@report-ajax');
    cy.get('#mob_ok').should('be.visible').click();
  });

  it('makes you move the pin if not on a road', function() {
    cy.pickCategory('Roads & Pavements');
    cy.wait('@roads-layer');
    cy.nextPageReporting();
    cy.pickSubcategory('Roads & Pavements', 'Parks');
    cy.nextPageReporting();
    cy.contains('Please select a road on which to make a report.').should('be.visible');
  });

  it('asks you to move the pin for grass cutting reports', function() {
    cy.pickCategory('Grass, hedges and weeds');
    cy.wait('@roads-layer');
    cy.nextPageReporting();
    cy.pickSubcategory('Grass hedges and weeds', 'Grass cutting');
    cy.nextPageReporting();
    cy.contains('Please select a road on which to make a report.').should('be.visible');
  });
});
