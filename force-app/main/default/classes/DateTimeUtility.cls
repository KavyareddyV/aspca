global class DateTimeUtility {
    
    public class DateTimeUtilityException extends Exception{}
    
    public class Response {
        @InvocableVariable(label='isSuccess' ) 
        public boolean isSuccess;
        @InvocableVariable(label='Message' ) 
        public string message;
        @InvocableVariable(label='resultDate' ) 
        public Date resultDate;
        @InvocableVariable(label='resultDateTime' ) 
        public DateTime resultDateTime;
    }
    
    public class Request {
        @InvocableVariable(label='Datetime input' required=true) 
        public string dateTimeString;
        @InvocableVariable(label='Days to add' required=true) 
        public Integer days;
        @InvocableVariable(label='Type of request Date/DateTime'required=true ) 
        public string requestType;
    }
    
    @InvocableMethod(label='Add business days to a date/datetime' category='Uncategorized')
    public static List<Response> getDate(List<Request> requests) {
        List<Response> results = new List<Response>();
        Date d = system.today();
        for(Request dtr : requests){
            Response result = new Response();
            try{
                if((dtr.dateTimeString == null || dtr.dateTimeString == '')){ 
                    throw new DateTimeUtilityException('Datetime string cannot be null error');
                }
                
                switch on dtr.requestType.toLowerCase(){
                    when 'date'{
                        d = Date.parse(dtr.dateTimeString);
                    }
                    when 'datetime'{
                        DateTime dt = DateTime.parse(dtr.dateTimeString);
                        d = Date.newInstance(dt.year(),dt.month(),dt.day());
                    }
                    when else {
                        throw new DateTimeUtilityException('Pass correct requestType Date/DateTime'); 
                    }
                }
                result.isSuccess = true;
                Date newDate = AddBusinessDays(d, dtr.days );
                result.resultDate = newDate;
                result.resultDateTime = datetime.newInstance(newDate.year(), newDate.month(),newDate.day());
            }catch(Exception ex){
                result.isSuccess = false;
                result.message = ex.getCause() +' - '+ ex.getMessage() ;
            }
            results.add(result);
        }
        return results;
    }
    
    //Add business days to a date
    public static Date AddBusinessDays(Date startDate, Integer businessDaysToAdd )  {
        Date finalDate = startDate;
        Integer direction = businessDaysToAdd < 0 ? -1 : 1;
        while(businessDaysToAdd != 0){
            finalDate = finalDate.addDays(direction);
            if (!IsWeekend(finalDate)){
                businessDaysToAdd -= direction;
            }
        }
        return finalDate;
    }
    
    //Check if a date is a weekend day
    public static Boolean IsWeekend(Date myDate){
        String myDateString = Datetime.newInstance(myDate.year(), myDate.month(),myDate.day()).format('EEE');
        return 'Sat'.equals(myDateString) || 'Sun'.equals(myDateString);
    }
}