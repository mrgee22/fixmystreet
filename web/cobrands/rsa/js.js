$(function () {

    $('#mapForm').on('click', '.js-reporting-page--next', function (e) {

        var selectedCategory = $('#mapForm input[name=category]:checked');
        var subCat = $('#form_subcategory_row input:radio:checked');
        var title = $('input[name=title]');
        var detail = $('textarea[name=detail]');

        if (title.length > 0) {
            $(title).val(selectedCategory.val());

            if (subCat.length > 0) {
                $(detail).val(subCat.val() + ':');
            }

        }
        // e.preventDefault();
        // var v = $(this).closest('form').validate();
        // if (!v.form()) {
        //     v.focusInvalid();
        //     return;
        // }
        // fixmystreet.pageController.toPage('next');
    });
});