component extends="org.lucee.cfml.test.LuceeTestCase"	{

    function run( testResults , testBox ) {

        setup();

        function setup(){
            variables.adminRoot = "/lucee/admin/"; // doesn't work, throws .lex error???
            variables.SERVERADMINPASSWORD = "webweb";
            /*
             [/lucee/admin/web.cfm] [zip://C:\work\lucee\temp\archive\base\lucee-server\context\context\lucee-admin.lar!/web.cfm] not found
            [java]    [script]                 /Users/mic/Projects/Lucee5/source/cfml/context/admin/server.cfm:2
            */

            variables.adminRoot = "http://127.0.0.1:8888/lucee/admin/";
            //variables.adminPage = "server.cfm"; 
            variables.adminPage = "server.cfm"; // server.cfm or web.cfm don't work???
            
            variables.cookies = {}; // need to be authenticated to the admin, for subsequent requests after login
        }

        private function remoteRequest( template, urls={}, forms={}, cookies={}, method="get" ) localmode=true {
            systemOutput( "-----------", true );
            systemOutput( arguments.template, true );
            http url=#arguments.template# result="res" method=method{
                loop collection=arguments.urls key="k" value="v" {
                    httpparam type="url" name=k value=v;
                }
                if (method == "post"){
                    loop collection=arguments.forms key="k" value="v" {
                        httpparam type="form" name=k value=v;
                    }
                }
                loop collection=arguments.cookies key="k" value="v" {
                    httpparam type="cookie" name=k value=v;
                }
            }
            res.status=res.status_code;
            return res;
        }
       
        describe(title="Testing Lucee Admin pages", asyncAll=false, body=function(){
            setup();
            
            it( title="Login to admin", body=function(){
                //systemOutput("------------- login to admin", true);
                local.loginResult = remoteRequest(
                    template: adminRoot & adminPage, 
                    forms: {
                        method: "post",
                        login_passwordserver: variables.SERVERADMINPASSWORD,
                        lang: "en",
                        rememberMe: "s",
                        submit: "submit"
                    }
                );
                systemOutput(loginResult, true);
                expect( loginResult.status ).toBe( 200, "Status code" );

                variables.cookies = {};
                loop query=loginResult.cookies {
                    variables.cookies[ loginResult.cookies.name ] = loginResult.cookies.value;
                }
                systemOutput(variables.cookies, true);
            });

            it( title="Fetch and test admin pages", body=function(){
                systemOutput("------------- get admin urls", true);
                // adminPage = "server.cfm";
                local._adminUrls = remoteRequest(
                    template: adminRoot & adminPage,
                    urls : { testUrls: true },
                    cookies: variables.cookies
                );
                
                expect( _adminUrls.status ).toBe( 200, "Status Code" );
                expect( isJson( _adminUrls.fileContent ) ).toBeTrue();
                local.adminUrls = deserializeJson( _adminUrls.fileContent );
                expect( adminUrls ).toBeArray();
                systemOutput( adminUrls, true );
                systemOutput( "", true );
                loop array="#adminUrls#" item="local.testUrl" {
                    checkUrl( adminRoot, local.testUrl, 200 );
                }
            });
            /*
            it( title="check admin extension pages", body=function(){
                local.extUrls = [];
                local.exts = ExtensionList();
                loop query=exts {
                    arrayAppend( extUrls, 
                        "#variables.adminPage#?action=ext.applications&action2=detail&id=#exts.id#&name=#URLEncodedFormat(exts.name)#"
                    );
                }
                loop array="#extUrls#" item="local.testUrl" {
                    checkUrl( adminRoot, local.testUrl, 200 );
                }
            });

            it( title="check missing admin extension page", skip=true, body=function() {
                local.missingExtUrl = "#variables.adminPage#?action=ext.applications&action2=detail&id=missing&name=missing";
                checkUrl( adminRoot, missingExtUrl, 404 );
            });

            xit( title="check admin 302", body=function(){
                // redirect (not logged in)
                checkUrl( adminRoot, "web.cfm?action=ext.applications", 302 );
            });

            it( title="check admin 404", body=function(){
                // not found (page doens't exist )
                checkUrl( adminRoot, "#variables.adminPage#?action=i.dont.exist", 404 );
            });

            it( title="check admin 500", body=function(){
                // 500 (mappng doesn't exist)
                checkUrl( adminRoot, "#variables.adminPage#?action=resources.mappings&action2=create&virtual=/lucee/adminMissing", 500 );
            });
            */
        });
    }

    private function checkUrl( required string adminRoot, required string testUrl, required numeric statusCode ){
        local.page =arguments.testUrl; // i.e "server.cfm?action=plugin&plugin=PerformanceAnalyzer"
        // systemOutput("", true );
        
        local.start = getTickCount();
        try {
            local.result = remoteRequest(
                template: page & "&rawError=true",
                cookies: variables.cookies
            );
            local.result.status = res.status_code;
        } catch(e) {
            if ( arguments.statusCode neq 500 ){
                rethrow;
            } else {
                local.result = {
                    status: 500,
                    fileContent: e.message & " " & e.detail & e.stacktrace
                };
            }
        }
        local.TAB = chr(9);
        if (structCount(local.result)){
            systemOutput( TAB & TAB & adminRoot & page & " " & TAB & NumberFormat( getTickCount()-local.start ) & " ms", true );
        }
        // this expect() maybe isn't even needed as remoteRequest throws the stack trace anyway??
        // systemOutput( local.result.headers, true );
        //expect( local.result.status ).toBeBetween( 200, 399, adminRoot & page & " returned status code: " & local.result.status);
        if ( local.result.status neq arguments.statusCode )
            systemOutput( trim(local.result.filecontent), true );
        expect( local.result.status ).toBe( arguments.statusCode, 
            arguments.adminRoot & page & " returned status code: " & local.result.status );
    }
}